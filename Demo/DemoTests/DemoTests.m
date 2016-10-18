//
//  DemoTests.m
//  DemoTests
//
//  Created by 符现超 on 16/9/30.
//  Copyright © 2016年 Zero.D.Saber. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ZDNetworkHelper.h"

@interface DemoTests : XCTestCase

@end

@implementation DemoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

/// 性能测试
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testZDNetwork {
    
}

- (void)testAsyncExample {
    NSString *testURL = @"http://baike.baidu.com/api/openapi/BaikeLemmaCardApi?scope=103&format=json&appid=379020&bk_key=贾静雯&bk_length=600";
    XCTestExpectation *exp = [self expectationWithDescription:@"出错原因~~~"];
    
    NSOperationQueue *zd_queue = [[NSOperationQueue alloc] init];
    [zd_queue addOperationWithBlock:^{
        [[ZDNetworkHelper shareInstance] requestWithURL:testURL params:nil httpMethod:HttpMethod_GET progress:^(NSProgress * _Nonnull progress, CGFloat progressValue) {
            NSLog(@"进度 == %0.1f", progressValue);
        } success:^(id  _Nullable responseObject) {
            NSLog(@"请求成功===> %@", responseObject);
            // 此处类似于信号量中的发送信号或者promise中的完成事件
            [exp fulfill];
        } failure:^(NSError * _Nonnull error) {
            NSLog(@"请求失败---> %@", error);
        }];
    }];
    
    // 超出时间限制后报错，测试不通过
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"-----> %@", error);
        }
    }];
}

@end
