[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/faimin/ZDAFNetWorkHelper/blob/master/LICENSE)&nbsp;
[![Language](http://img.shields.io/badge/language-objc-brightgreen.svg?style=flat
)](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html)&nbsp;
## ZDNetWorkHelper
对[AFNetworking](https://github.com/AFNetworking/AFNetworking) `GET`、`POST`、`DownLoad`、`Upload` 请求的二次封装

-------

```objc
- (nullable NSURLSessionDataTask *)requestWithURL:(NSString *)URLString
                                           params:(nullable id)params
                                       httpMethod:(HttpMethod)httpMethod
                                         progress:(ProgressHandle)progressBlock
                                          success:(nullable SuccessHandle)successBlock
                                          failure:(nullable FailureHandle)failureBlock;

- (nullable NSURLSessionDataTask *)requestWithURL:(NSString *)URLString
                                           params:(nullable id)params
                                       httpMethod:(HttpMethod)httpMethod
                                   cachedResponse:(nullable CachedHandle)cachedBlock
                                         progress:(ProgressHandle)progressBlock
                                          success:(SuccessHandle)successBlock
                                          failure:(FailureHandle)failureBlock;

- (nullable NSURLSessionDownloadTask *)downloadWithURL:(NSString *)urlString
                                            saveToPath:(nullable NSString *)savePath
                                              progress:(ProgressHandle)progressBlock
                                               success:(SuccessHandle)successBlock // 回调的是filePath
                                               failure:(FailureHandle)failureBlock;

- (void)uploadFileWithURL:(NSString *)urlString
                 filePath:(NSString *)filePath
                 progress:(ProgressHandle)progressBlock
                  success:(SuccessHandle)successBlock
                  failure:(FailureHandle)failureBlock;

/// 异步上传,回调数组中的url顺序与添加图片时的顺序一一对应
- (void)uploadDataWithURL:(NSString *)urlString
           dataDictionary:(NSDictionary *)dataDic
               completion:(void(^)(NSArray *result))completionBlock;

- (void)uploadFileWithURL:(NSString *)urlString
                filePaths:(NSArray<NSString *> *)filePaths
               completion:(void(^)(NSArray *result))completionBlock;                                         
```

### Installation with CocoaPods
Add the following line to your Podfile.

```ruby
pod 'ZDNetWorkHelper', '~> 0.3.1'
```
Then, run the following command:

```ruby
$ pod install
```
### License
**ZDNetWorkHelper** is under an MIT license. See the [LICENSE](https://github.com/faimin/ZDNetWorkHelper/blob/master/LICENSE) file for more information.

