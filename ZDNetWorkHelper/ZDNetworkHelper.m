//
// ZDNetWorkService.m
// RequestNetWork
//
// Created by Zero on 14/11/21.
// Copyright (c) 2014年 Zero.D.Saber. All rights reserved.
//

#import "ZDNetworkHelper.h"
#import <pthread/pthread.h>
#import <CommonCrypto/CommonDigest.h>
#import "AFNetworkActivityIndicatorManager.h"
#import "AFNetworking.h"

#define Progress(progress) CGFloat progressValue = 0.0f;                                    \
                    if (progress.totalUnitCount > 0) {                                      \
                        progressValue = (CGFloat)progress.completedUnitCount / progress.totalUnitCount;                                                               \
                    }                                                                       \
                    progressBlock ? progressBlock(progress, progressValue) : nil;

static const NSTimeInterval timeoutInterval = 30;

static BOOL ZD_IsEmptyOrNil(NSString *string) {
    if (string == nil || string == NULL) return YES;
    if ([string isKindOfClass:[NSNull class]]) return YES;
    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return YES;
    
    return NO;
}

static NSString *ZD_MD5(NSString *string) {
    if (ZD_IsEmptyOrNil(string)) return nil;
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([string UTF8String], (int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    NSMutableString *ms = [NSMutableString string];
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", (int)(digest[i])];
    }
    return [ms copy];
}

static id ZD_DecodeData(id data) {
    if (!data) return nil;
    
    NSError *__autoreleasing error;
    id result = [data isKindOfClass:[NSData class]] ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error] : data;
    return result;
}

static NSString *ZD_CacheKey(NSString *URL, NSDictionary *parameters){
    if (!parameters) return URL;
    
    // 将参数字典转换成字符串
    NSError *__autoreleasing error = nil;
    NSData *stringData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error];
    NSString *paraString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@?%@", URL, paraString];
    
    return cacheKey;
}

#pragma mark -

@interface ZDURLCache : NSURLCache
/// 单例
+ (instancetype)urlCache;

/// 获取缓存
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request;

/// 储存缓存
- (void)storeCachedResponse:(NSURLResponse *)urlResponse
               responseObjc:(id)responseObjc
                 forRequest:(NSURLRequest *)request;

// 以下针对的是POST请求缓存，因为NSURLCache只支持GET请求
+ (id)getCacheResponseWithURL:(NSString *)url
                       params:(NSDictionary *)params;

+ (void)cacheResponseObject:(id)responseObject
                        url:(NSString *)urlString
                     params:(NSDictionary *)params;
@end


@interface ZDNetworkHelper ()
//@property (nonatomic, strong, readonly) AFHTTPSessionManager *httpSessionManager;
@end

static AFHTTPSessionManager *_httpSessionManager;
static BOOL _hasCertificate;
static ZDNetworkStatus _networkStatus;
@implementation ZDNetworkHelper
{
    //dispatch_semaphore_t _semaphore;
    pthread_mutex_t _lock;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

+ (void)initialize {
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    _httpSessionManager = [AFHTTPSessionManager manager];
    
    _httpSessionManager.requestSerializer.timeoutInterval = timeoutInterval;
    
    _httpSessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    
    _httpSessionManager.responseSerializer = ({
        AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingAllowFragments];
        jsonResponseSerializer.removesKeysWithNullValues = YES;
        jsonResponseSerializer;
    });
    
    ///`contentTypes`: http://www.iana.org/assignments/media-types/media-types.xhtml
    _httpSessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:
                                                                     @"text/plain",
                                                                     @"text/json",
                                                                     @"text/xml",
                                                                     @"text/html",
                                                                     @"text/javascript",
                                                                     @"application/json",
                                                                     @"application/javascript",
                                                                     @"application/xml",
                                                                     @"image/*",
                                                                     nil];
    
    // 监控网络
    [self detectNetworkStatus:^(ZDNetworkStatus status) {
        _networkStatus = status;
    }];
}

#pragma mark - Singleton

static ZDNetworkHelper *zdNetworkHelper = nil;
+ (instancetype)shareInstance {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		zdNetworkHelper = [[ZDNetworkHelper alloc] init];
	});
    
	return zdNetworkHelper;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //_semaphore = dispatch_semaphore_create(1);
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
        pthread_mutex_init(&_lock, &attr);
    }
    return self;
}

//+ (instancetype)allocWithZone:(struct _NSZone *)zone {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        zdNetworkHelper = [super allocWithZone:zone];
//    });
//    
//    return zdNetworkHelper;
//}
//
//- (id)copyWithZone:(NSZone *)zone {
//    return zdNetworkHelper;
//}

- (NSMutableDictionary *)allTasks {
    static NSMutableDictionary *_allTasks = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _allTasks = [[NSMutableDictionary alloc] init];
    });
    return _allTasks;
}

#pragma mark
//MARK:GET && POST请求
- (NSURLSessionDataTask *)requestWithURL:(NSString *)URLString
                                  params:(id)params
                              httpMethod:(HttpMethod)httpMethod
                                progress:(ProgressHandle)progressBlock
                                 success:(SuccessHandle)successBlock
                                 failure:(FailureHandle)failureBlock {
    return [self requestWithURL:URLString params:params httpMethod:httpMethod cachedResponse:nil progress:progressBlock success:successBlock failure:failureBlock];
}

- (NSURLSessionDataTask *)requestWithURL:(NSString *)URLString
                                  params:(id)params
                              httpMethod:(HttpMethod)httpMethod
                          cachedResponse:(CachedHandle)cachedBlock
                                progress:(ProgressHandle)progressBlock
                                 success:(SuccessHandle)successBlock
                                 failure:(FailureHandle)failureBlock {
	// 1.处理URL
    NSString *newURL = [self handleURL:URLString];
	
	// 2.发送请求
	NSURLSessionDataTask *sessionTask = nil;
	__weak __typeof(&*self) weakSelf = self;
    switch (httpMethod)
    {
        case HttpMethod_GET: {
            ZD_Log(@"\n❤️RealRequestURL❤️ = %@ 👽\n\n", ZD_CacheKey(newURL, params));
            // 读取本地缓存
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:newURL]];
            if (cachedBlock) {
                dispatch_queue_t zd_queue = dispatch_queue_create("ZD_Queue_GET", DISPATCH_QUEUE_CONCURRENT);
                dispatch_async(zd_queue, ^{
                    [NSURLCache setSharedURLCache:[ZDURLCache urlCache]];
                    NSCachedURLResponse *cachedResponse = [[ZDURLCache urlCache] cachedResponseForRequest:urlRequest];
                    id value = ZD_DecodeData(cachedResponse.data);
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        value ? cachedBlock(value) : nil;
                    });
                });
            }
            
            // 请求新的数据
            sessionTask = [_httpSessionManager GET:newURL parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
                Progress(downloadProgress)
            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                id result = ZD_DecodeData(responseObject);
                if (responseObject) {
                    [[ZDURLCache urlCache] storeCachedResponse:task.response responseObjc:result forRequest:urlRequest];
                }

                successBlock ? successBlock(result) : nil;
                [[strongSelf allTasks] setValue:nil forKey:URLString];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                failureBlock ? failureBlock(error) : nil;
                [[strongSelf allTasks] setValue:nil forKey:URLString];
            }];
            
            break;
        }
            
        case HttpMethod_POST: {
            BOOL isDataFile = NO;
            for (id value in [params allValues]) {
                if ([value isKindOfClass:[NSData class]]) {
                    isDataFile = YES;
                    break;
                }
                else if ([value isKindOfClass:[NSURL class]]) {
                    isDataFile = NO;
                    break;
                }
            }
            
            if (!isDataFile) {
                // 参数中不包含NSData类型
                if (cachedBlock) {
                    dispatch_queue_t zd_queue = dispatch_queue_create("ZD_Queue_POST", DISPATCH_QUEUE_CONCURRENT);
                    dispatch_async(zd_queue, ^{
                        id cachedResponse = [ZDURLCache getCacheResponseWithURL:newURL params:params];
                        id value = ZD_DecodeData(cachedResponse);
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            value ? cachedBlock(value) : nil;
                        });
                    });
                }
                
                sessionTask = [_httpSessionManager POST:newURL parameters:params progress:^(NSProgress * _Nonnull uploadProgress) {
                    Progress(uploadProgress)
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                    id result = ZD_DecodeData(responseObject);
                    if (responseObject) {
                        [ZDURLCache cacheResponseObject:result url:newURL params:params];
                    }
                    
                    successBlock ? successBlock(result) : nil;
                    [[strongSelf allTasks] setValue:nil forKey:URLString];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                    failureBlock ? failureBlock(error) : nil;
                    [[strongSelf allTasks] setValue:nil forKey:URLString];
                }];
            }
            else {
                // http://www.tuicool.com/articles/E3aIVra
                // 参数中包含NSData或者fileURL类型
                sessionTask = [_httpSessionManager POST:newURL parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                    for (NSString *key in [params allKeys]) {
                        id value = params[key];
                        // 判断参数是否是文件数据
                        if ([value isKindOfClass:[NSData class]]) {
                            // 将文件数据添加到formData中
                            // fileName后面一定要加后缀,否则上传文件会出错
                            [formData appendPartWithFileData:value
                                                        name:key
                                                    fileName:[NSString stringWithFormat:@"%@.jpg", key]
                                                    mimeType:@"image/jpeg"];
                        }
                        else if ([value isKindOfClass:[NSURL class]]) {
                            NSError *__autoreleasing error;
                            NSURL *localFileURL = value;
                            [formData appendPartWithFileURL:localFileURL
                                                       name:localFileURL.absoluteString
                                                   fileName:localFileURL.absoluteString
                                                   mimeType:@"image/jpeg"
                                                      error:&error];
                        }
                        else if ([value isKindOfClass:[NSString class]] && [(NSString *)value hasPrefix:@"http"]) {
                            NSError *__autoreleasing error;
                            NSString *urlStr = value;
                            [formData appendPartWithFileURL:[NSURL fileURLWithPath:urlStr]
                                                       name:urlStr
                                                   fileName:urlStr
                                                   mimeType:@"image/jpeg"
                                                      error:&error];
                        }
                    }
                } progress:^(NSProgress * _Nonnull uploadProgress) {
                    Progress(uploadProgress)
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                    successBlock ? successBlock(ZD_DecodeData(responseObject)) : nil;
                    [[strongSelf allTasks] setValue:nil forKey:URLString];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                    failureBlock ? failureBlock(error) : nil;
                    [[strongSelf allTasks] setValue:nil forKey:URLString];
                }];
            }
            
            break;
        }
            
        default: {
            break;
        }
    }

    [[self allTasks] setValue:sessionTask forKey:URLString];
    
    return sessionTask;
}

//MARK: Download
- (NSURLSessionDownloadTask *)downloadWithURL:(NSString *)urlString
                                   saveToPath:(NSString *)savePath
                                     progress:(ProgressHandle)progressBlock
                                      success:(SuccessHandle)successBlock
                                      failure:(FailureHandle)failureBlock {
    if (ZD_IsEmptyOrNil(urlString)) return nil;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    __weak __typeof(&*self)weakSelf = self;
    NSURLSessionDownloadTask *downloadTask = [_httpSessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        Progress(downloadProgress)
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSString *downloadPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:savePath ? : @"ZD_Download"];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDirectory;
        BOOL isExistFile = [fileManager fileExistsAtPath:downloadPath isDirectory:&isDirectory];
        if (!(isExistFile && isDirectory)) {
            NSError *__autoreleasing error;
            [fileManager createDirectoryAtPath:downloadPath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) ZD_Log(@"创建文件夹时的错误信息----->%@", error.localizedDescription);
        }
        NSString *savedPath = [downloadPath stringByAppendingPathComponent:response.suggestedFilename];
        ZD_Log(@"下载完成,文件路径 = %@", savedPath);
        
        return [NSURL fileURLWithPath:savedPath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        [[strongSelf allTasks] setValue:nil forKey:urlString];
        
        (successBlock && filePath) ? successBlock(filePath.absoluteString) : nil;
        (failureBlock && error) ? failureBlock(error) : nil;
    }];
    
    [downloadTask resume];
    
    [[self allTasks] setValue:downloadTask forKey:urlString];
    
    return downloadTask;
}

//MARK: Upload
- (void)uploadFileWithURL:(NSString *)urlString
                 filePath:(NSString *)filePath
                 progress:(ProgressHandle)progressBlock
                  success:(SuccessHandle)successBlock
                  failure:(FailureHandle)failureBlock {
    if (ZD_IsEmptyOrNil(urlString) || ZD_IsEmptyOrNil(filePath)) return;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSURL *fileURL = [NSURL URLWithString:filePath];
    
    [_httpSessionManager uploadTaskWithRequest:request fromFile:fileURL progress:^(NSProgress * _Nonnull uploadProgress) {
        Progress(uploadProgress)
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        (responseObject && successBlock) ? successBlock(responseObject) : nil;
        (error && failureBlock) ? failureBlock(error) : nil;
    }];
}

- (void)uploadDataWithURL:(NSString *)urlString
           dataDictionary:(NSDictionary *)dataDic
               completion:(void(^)(NSArray *result))completionBlock {
    NSUInteger dataCount = dataDic.count;
    NSMutableArray *resultArr = [[NSMutableArray alloc] initWithCapacity:dataCount];
    for (NSInteger i = 0; i < dataCount; i++) {
        [resultArr addObject:[NSNull null]];
    }
    
    dispatch_group_t zdGroup = dispatch_group_create();
    dispatch_semaphore_t zdSemaphore = dispatch_semaphore_create(1);
    
    for (NSInteger i = 0; i < dataCount; i++) {
        dispatch_group_enter(zdGroup);
        [self requestWithURL:urlString params:dataDic httpMethod:HttpMethod_POST progress:^(NSProgress * _Nonnull progress, CGFloat progressValue) {
            //do nothing
        } success:^(id  _Nullable responseObject) {
            dispatch_semaphore_wait(zdSemaphore, DISPATCH_TIME_FOREVER);
            resultArr[i] = responseObject;
            dispatch_semaphore_signal(zdSemaphore);
            dispatch_group_leave(zdGroup);
        } failure:^(NSError * _Nonnull error) {
            dispatch_group_leave(zdGroup);
        }];
    }
    
    dispatch_group_notify(zdGroup, dispatch_get_main_queue(), ^{
        completionBlock(resultArr);
    });
}

- (void)uploadFileWithURL:(NSString *)urlString
                filePaths:(NSArray<NSString *> *)filePaths
               completion:(void(^)(NSArray *result))completionBlock {
    NSUInteger fileCount = filePaths.count;
    NSMutableArray *resultArr = [[NSMutableArray alloc] initWithCapacity:fileCount];
    for (NSInteger i = 0; i < fileCount; i++) {
        [resultArr addObject:[NSNull null]];
    }
    
    dispatch_group_t zdGroup = dispatch_group_create();
    dispatch_semaphore_t zdSemaphore = dispatch_semaphore_create(1);
    
    for (NSInteger i = 0; i < fileCount; i++) {
        dispatch_group_enter(zdGroup);
        [self uploadFileWithURL:urlString filePath:filePaths[i] progress:^(NSProgress * _Nonnull progress, CGFloat progressValue) {
            // do nothing
        } success:^(id  _Nullable responseObject) {
            dispatch_semaphore_wait(zdSemaphore, DISPATCH_TIME_FOREVER);
            resultArr[i] = responseObject;
            dispatch_semaphore_signal(zdSemaphore);
            dispatch_group_leave(zdGroup);
        } failure:^(NSError * _Nonnull error) {
            dispatch_group_leave(zdGroup);
        }];
    }
    
    dispatch_group_notify(zdGroup, dispatch_get_main_queue(), ^{
        completionBlock(resultArr);
    });
}

//MARK:取消单一或者全部任务
- (void)cancelTaskWithURL:(NSString *)urlString {
    if (ZD_IsEmptyOrNil(urlString)) return;
    //dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    pthread_mutex_lock(&_lock);
    NSURLSessionTask *task = [self allTasks][urlString];
    [task cancel];
    task ? [[self allTasks] setValue:nil forKey:urlString] : nil;
    //dispatch_semaphore_signal(_semaphore);
    pthread_mutex_unlock(&_lock);
}

- (void)cancelAllTasks {
    //dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    pthread_mutex_lock(&_lock);
    for (NSURLSessionTask *task in [[self allTasks] allValues]) {
        [task cancel];
    }
    //dispatch_semaphore_signal(_semaphore);
    pthread_mutex_unlock(&_lock);
}

- (void)cancelAllOperations {
    [_httpSessionManager.operationQueue cancelAllOperations];
}

- (void)invalidateSession {
    [_httpSessionManager invalidateSessionCancelingTasks:YES];
}

#pragma mark - Private Method
- (NSString *)handleURL:(NSString *)URLString {
    if (ZD_IsEmptyOrNil(URLString) && ZD_IsEmptyOrNil(self.baseURLString)) return @"";
    
    NSString *originURL = [NSString stringWithFormat:@"%@%@", (self.baseURLString ?: @""), URLString];
    NSString *tempURL = [originURL stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *newURL = @"";
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
        newURL = [tempURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    else {
        newURL = [tempURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return newURL;
}

+ (void)detectNetworkStatus:(void(^)(ZDNetworkStatus status))networkStatus {
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    [reachabilityManager startMonitoring];
    [reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
                case AFNetworkReachabilityStatusUnknown:
                networkStatus(ZDNetworkStatusUnknown);
                break;
                
                case AFNetworkReachabilityStatusNotReachable:
                networkStatus(ZDNetworkStatusNotReachable);
                break;
                
                case AFNetworkReachabilityStatusReachableViaWWAN:
                networkStatus(ZDNetworkStatusWWAN);
                break;
                
                case AFNetworkReachabilityStatusReachableViaWiFi:
                networkStatus(ZDNetworkStatusWiFi);
                break;
        }
    }];
}

#pragma mark - Property

+ (void)setHasCertificate:(BOOL)hasCertificate {
    /// http://www.tuicool.com/articles/6Vfuu2M 验证HTTPS请求证书
    _hasCertificate = hasCertificate;
    if (hasCertificate) {
        ///有证书时AF会自动从bundle中寻找并加载cer格式的证书
        _httpSessionManager.securityPolicy = ({
            AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModePublicKey];
            securityPolicy.allowInvalidCertificates = YES;
            securityPolicy;
        });
    }
    else {
        _httpSessionManager.securityPolicy = ({
            AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
            securityPolicy.allowInvalidCertificates = YES;
            securityPolicy.validatesDomainName = NO;
            securityPolicy;
        });;
    }
}

+ (BOOL)hasCertificate {
    return _hasCertificate;
}

+ (ZDNetworkStatus)networkStatus {
    return _networkStatus;
}

@end


#pragma mark - ZDCache
#pragma mark -

#define ZD_M (1024 * 1024)  // 1M
#define ZD_MAX_MEMORY_CACHE_SIZE (10 * ZD_M)
#define ZD_MAX_DISK_CACHE_SIZE (30 * ZD_M)
#define ZD_CACHE_PATH ([NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"ZDNetworkCache"])

static NSString * const ZDURLCachedExpirationKey = @"ZDURLCachedExpirationDateKey";
static NSTimeInterval const ZDURLCacheExpirationInterval = 7 * 24 * 60 * 60;

@implementation ZDURLCache

+ (instancetype)urlCache {
    static ZDURLCache *_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [[ZDURLCache alloc] initWithMemoryCapacity:ZD_MAX_MEMORY_CACHE_SIZE diskCapacity:ZD_MAX_DISK_CACHE_SIZE diskPath:nil];
    });
    return _cache;
}

#pragma mark - 缓存GET请求
/// 读取缓存(GET请求)
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    NSCachedURLResponse *cachedResponse = [super cachedResponseForRequest:request];
    if (cachedResponse) {
        NSDate *cacheDate = cachedResponse.userInfo[ZDURLCachedExpirationKey];
        NSDate *cacheExpirationDate = [cacheDate dateByAddingTimeInterval:ZDURLCacheExpirationInterval];
        // 过期之后移除
        if ([cacheExpirationDate compare:[NSDate date]] == NSOrderedAscending) {
            [self removeCachedResponseForRequest:request];
            return nil;
        }
    }
    return cachedResponse;
}

/// 存储缓存
- (void)storeCachedResponse:(NSURLResponse *)urlResponse
               responseObjc:(id)responseObjc
                 forRequest:(NSURLRequest *)request {
    if (!responseObjc) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *__autoreleasing error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:responseObjc options:NSJSONWritingPrettyPrinted error:&error];
        
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        userInfo[ZDURLCachedExpirationKey] = [NSDate date];
        
        NSCachedURLResponse *newCachedResponse = [[NSCachedURLResponse alloc] initWithResponse:urlResponse data:data userInfo:userInfo storagePolicy:NSURLCacheStorageAllowed];
        
        [super storeCachedResponse:newCachedResponse forRequest:request];
    });
}

#pragma mark - 缓存POST请求
+ (void)cacheResponseObject:(id)responseObject
                        url:(NSString *)urlString
                     params:(NSDictionary *)params {
    if (!ZD_IsEmptyOrNil(urlString) && responseObject && ![responseObject isKindOfClass:[NSNull class]]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *directoryPath = ZD_CACHE_PATH;
            
            NSError *__autoreleasing error = nil;
            BOOL isFileExist = [[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil];
            if (!isFileExist) {
                [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:&error];
                if (error) ZD_Log(@"创建文件夹失败 == %@", error);
                error = nil;
            }
            
            NSString *originString = ZD_CacheKey(urlString, params);
            NSString *path = [directoryPath stringByAppendingPathComponent:ZD_MD5(originString)];
            
            NSData *data = nil;
            if ([responseObject isKindOfClass:[NSData class]]) {
                data = responseObject;
            }
            else {
                data = [NSJSONSerialization dataWithJSONObject:responseObject
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
            }
            
            if (data && !error) {
                [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
            }
        });
    }
}

+ (id)getCacheResponseWithURL:(NSString *)url
                       params:(NSDictionary *)params {
    if (!url) return nil;

    NSString *directoryPath = ZD_CACHE_PATH;
    NSString *originString = ZD_CacheKey(url, params);;
    
    NSString *path = [directoryPath stringByAppendingPathComponent:ZD_MD5(originString)];
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    id cacheData = nil;
    if (data) {
        NSError *__autoreleasing error = nil;
        cacheData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (error) ZD_Log(@"%@", error);
    }
    return cacheData;
}

#pragma mark
+ (unsigned long long)totalCacheSize {
    NSString *directoryPath = ZD_CACHE_PATH;
    
    BOOL isDir = NO;
    unsigned long long total = 0;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDir]) {
        if (isDir) {
            NSError *__autoreleasing error = nil;
            NSArray<NSString *> *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&error];
            if (error == nil) {
                for (NSString *subPath in array) {
                    NSString *path = [directoryPath stringByAppendingPathComponent:subPath];
                    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
                    if (!error) {
                        total += [dict[NSFileSize] unsignedIntegerValue];
                    }
                }
            }
        }
    }
    return total;
}

+ (void)clearCaches {
    NSString *directoryPath = ZD_CACHE_PATH;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil]) {
        NSError *__autoreleasing error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:directoryPath error:&error];
    }
}

@end


