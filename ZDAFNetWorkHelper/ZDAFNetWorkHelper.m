//
// ZSNetWorkService.m
// RequestNetWork
//
// Created by Bourne on 14/11/21.
// Copyright (c) 2014年 Zero.D.Saber. All rights reserved.
//

#import "ZDAFNetWorkHelper.h"
#import "AFNetworkActivityIndicatorManager.h"

@interface ZDAFNetWorkHelper ()
@property (nonatomic, strong) AFHTTPSessionManager *httpSessionManager;
@property (nonatomic, assign) BOOL hasCertificate;  ///< 有无证书，default is NO
@end

@implementation ZDAFNetWorkHelper

#pragma mark - Singleton

static ZDAFNetWorkHelper *zdAFHelper = nil;
+ (instancetype)shareInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		zdAFHelper = [[ZDAFNetWorkHelper alloc] init];
        [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
	});
    
	return zdAFHelper;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zdAFHelper = [super allocWithZone:zone];
    });
    
    return zdAFHelper;
}

- (id)copyWithZone:(NSZone *)zone
{
    return zdAFHelper;
}

#pragma mark - GET && POST请求
// 返回值:NSURLSessionTask *
- (NSURLSessionDataTask *)requestWithURL:(NSString *)URLString
                                  params:(id)params
                              httpMethod:(HttpMethod)httpMethod
                                progress:(ProgressHandle)progressBlock
                                 success:(SuccessHandle)successBlock
                                 failure:(FailureHandle)failureBlock
{
	// 1.处理URL
    NSString *URL = [[NSString stringWithFormat:@"%@%@", (self.baseURLString ? : @""), URLString] stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0) {
        URL = [URL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];// controlCharacterSet
    }
    else {
        URL = [URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
	// 2.初始化请求管理对象，设置规则
	
	// 3.发送请求
	NSURLSessionDataTask *sessionTask = nil;
	__weak __typeof(&*self) weakSelf = self;
    switch (httpMethod) {
        case HttpMethod_GET: {
            sessionTask = [self.httpSessionManager GET:URL parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
                if (progressBlock) {
                    progressBlock(downloadProgress);
                }
            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                __strong __typeof(&*weakSelf) strongSelf = weakSelf;
                if (successBlock) {
                    successBlock([strongSelf decodeData:responseObject]);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (failureBlock) {
                    failureBlock(error);
                }
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
                sessionTask = [self.httpSessionManager POST:URL parameters:params progress:^(NSProgress * _Nonnull uploadProgress) {
                    if (progressBlock) {
                        progressBlock(uploadProgress);
                    }
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    __strong __typeof(&*weakSelf) strongSelf = weakSelf;
                    if (successBlock) {
                        successBlock([strongSelf decodeData:responseObject]);
                    }
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    if (failureBlock) {
                        failureBlock(error);
                    }
                }];
            }
            else {
                //http://www.tuicool.com/articles/E3aIVra
                // 参数中包含NSData或者fileURL类型
                sessionTask = [self.httpSessionManager POST:URL parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                    for (NSString *key in [params allKeys]) {
                        id value = params[key];
                        // 判断参数是否是文件数据
                        if ([value isKindOfClass:[NSData class]]) {
                            // 将文件数据添加到formData中
                            // image/jpeg、text/plain、text/html、application/octet-stream , fileName后面一定要加后缀,否则上传文件会出错
                            [formData appendPartWithFileData:value
                                                        name:key
                                                    fileName:[NSString stringWithFormat:@"%@.jpg", key]
                                                    mimeType:@"image/jpg"];
                        }
                        else if ([value isKindOfClass:[NSURL class]]) {
                            NSError *error;
                            NSURL *localFileURL = value;
                            [formData appendPartWithFileURL:localFileURL
                                                       name:localFileURL.absoluteString
                                                   fileName:localFileURL.absoluteString
                                                   mimeType:@"image/jpg"
                                                      error:&error];
                        }
                        else if ([value isKindOfClass:[NSString class]] && [(NSString *)value hasPrefix:@"http"]) {
                            NSError *error;
                            NSString *urlStr = value;
                            [formData appendPartWithFileURL:[NSURL fileURLWithPath:urlStr]
                                                       name:urlStr
                                                   fileName:urlStr
                                                   mimeType:@"image/jpg"
                                                      error:&error];
                        }
                    }
                } progress:^(NSProgress * _Nonnull uploadProgress) {
                    if (progressBlock) {
                        progressBlock(uploadProgress);
                    }
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    __strong __typeof(&*weakSelf) strongSelf = weakSelf;
                    if (successBlock) {
                        successBlock([strongSelf decodeData:responseObject]);
                    }
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    if (failureBlock) {
                        failureBlock(error);
                    }
                }];
            }

            break;
        }
            
        default: {
            break;
        }
    }

    return sessionTask;
}

#pragma mark - Upload

- (void)uploadDataWithURLString:(NSString *)urlString dataDictionary:(NSDictionary *)dataDic completion:(void(^)(id responseObject))completionBlock
{
//    NSError * __autoreleasing error;
//    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:urlString parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
//        NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
//        [formData appendPartWithFileData:imageData name:@"file" fileName:@"someFileName" mimeType:@"multipart/form-data"];
//    } error:&error];
    
    NSUInteger dataCount = dataDic.count;
    NSMutableArray *resultArr = [[NSMutableArray alloc] initWithCapacity:dataCount];
    for (NSInteger i = 0; i < dataCount; i++) {
        [resultArr addObject:[NSNull null]];
    }
    
    dispatch_group_t zdGroup = dispatch_group_create();
    dispatch_semaphore_t zdSemaphore = dispatch_semaphore_create(1);
    
    for (NSInteger i = 0; i < dataCount; i++) {
        dispatch_group_enter(zdGroup);
        [self requestWithURL:urlString params:dataDic httpMethod:HttpMethod_POST progress:^(NSProgress * _Nonnull progress) {
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

#pragma mark - Private Method
///解析数据
- (id)decodeData:(id)data
{
    if (!data) {
        return nil;
    }
	NSError *error;
	return [data isKindOfClass:[NSData class]] ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error] : data;
}

#pragma mark - Operations

- (void)cancelAllOperations
{
    [[ZDAFNetWorkHelper shareInstance].httpSessionManager.operationQueue cancelAllOperations];
}

#pragma mark - Property

- (AFHTTPSessionManager *)httpSessionManager
{
    if (!_httpSessionManager) {
        _httpSessionManager = [AFHTTPSessionManager manager];
        _httpSessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/plain", @"text/html", @"application/rss+xml", @"application/soap+xml", @"application/xml", nil];
        _httpSessionManager.requestSerializer.timeoutInterval = 10;
        self.hasCertificate = NO;
        /// http://www.tuicool.com/articles/6Vfuu2M 验证HTTPS请求证书
        if (self.hasCertificate) {
            ///有cer证书时AF会自动从bundle中寻找并加载cer格式的证书
            AFSecurityPolicy *securityPolicy = ({
                AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModePublicKey];
                securityPolicy.allowInvalidCertificates = YES;
                securityPolicy;
            });
            _httpSessionManager.securityPolicy = securityPolicy;
        }
        else {
            ///无cer证书的情况,忽略证书,实现Https请求
            AFSecurityPolicy *securityPolicy = ({
                AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
                securityPolicy.allowInvalidCertificates = YES;
                securityPolicy.validatesDomainName = NO;
                securityPolicy;
            });
            _httpSessionManager.securityPolicy = securityPolicy;
        }
    }
    return _httpSessionManager;
}

@end


/**
 *  @discussion   下面如果写成 sessionManager.responseSerializer = [AFJSONResponseSerializer serializer]会出现1016的错误.这种方法只能解析返回的是Json类型的数据,其他类型无法解析。
 *
 *  @add
 *
 *  AFJSONResponseSerializer *jsonResponse = [AFJSONResponseSerializer serializer];
 *  jsonResponse.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/plain",@"text/html", nil];
 *  sessionManager.responseSerializer = jsonResponse;
 *
 *  这样就可以自动解析了
 *  此处我是手动解析的,因为有的数据还是无法自动解析
 */

// 4.返回数据的格式(默认是json格式)

/**
 *  当AF带的方法不能自动解析的时候再打开下面的
 *  此处我是让它返回的是NSData二进制数据类型,然后自己手动解析;
 *  默认情况下,提交的是二进制数据请求,返回Json格式的数据
 */
// sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];

