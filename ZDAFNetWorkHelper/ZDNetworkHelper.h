//
//  ZAFNetWorkService.h
//  RequestNetWork
//
//  Created by Zero on 14/11/21.
//  Copyright (c) 2014年 Zero.D.Saber. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

const NSTimeInterval timeoutInterval = 10;

typedef NS_ENUM (NSUInteger, HttpMethod) {
	HttpMethod_GET,
	HttpMethod_POST,
};
typedef NS_ENUM(NSInteger, ZDNetworkStatus) {
    ZDNetworkStatusUnknown          = -1,
    ZDNetworkStatusNotReachable     = 0,
    ZDNetworkStatusWWAN             = 1,
    ZDNetworkStatusWiFi             = 2,
};

/// 用于回调请求成功或者失败的信息
typedef void(^SuccessHandle)(id _Nullable responseObject);
typedef void(^FailureHandle)(NSError *_Nonnull error);
typedef void(^ProgressHandle)(NSProgress *_Nonnull progress);


NS_ASSUME_NONNULL_BEGIN
@interface ZDNetworkHelper : NSObject

@property (nonatomic, copy, nullable) NSString *baseURLString;      ///< baseURL
@property (nonatomic, assign) ZDNetworkStatus networkStatus;   ///< 网络状态

/// @brief 单例
/// @return 实例化后的selfClass
+ (instancetype)shareInstance;


/// @abstract GET && POST请求
///
/// @param urlString : 请求地址
/// @param params : 请求参数
/// @param httpMethod : GET/POST 请求
/// @param successBlock/failureBlock : 回调block
/// @discussion
- (nullable NSURLSessionDataTask *)requestWithURL:(NSString *)URLString
                                           params:(nullable id)params
                                       httpMethod:(HttpMethod)httpMethod
                                         progress:(ProgressHandle)progressBlock
                                          success:(nullable SuccessHandle)successBlock
                                          failure:(nullable FailureHandle)failureBlock;

- (void)cancelAllOperations;

/// 异步上传,顺序返回
- (void)uploadDataWithURLString:(NSString *)urlString
                 dataDictionary:(NSDictionary *)dataDic
                     completion:(void(^)(id responseObject))completionBlock;

@end
NS_ASSUME_NONNULL_END
