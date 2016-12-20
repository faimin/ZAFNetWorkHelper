//
//  ViewController.m
//  Demo
//
//  Created by 符现超 on 16/9/30.
//  Copyright © 2016年 Zero.D.Saber. All rights reserved.
//

#import "ViewController.h"
#import "ZDNetworkHelper.h"

NSString *const url1 = @"https://daka.facenano.com/checkin/v1/app_binding?phone_number=18700000001&app_version_code=2&device=mobile_ios&company_tag=iPhone-demo&phone_imei=6D56F277-0AAA-4F32-AD01-6C55AEE75964&verification_code=3216";
NSString *const url2 = @"http://api.douban.com/v2/movie/top250";
NSString *const url3 = @"http://baike.baidu.com/api/openapi/BaikeLemmaCardApi?scope=103&format=json&appid=379020&bk_key=成龙&bk_length=600";

NSString *const downloadURL1 = @"http://data.vod.itc.cn/?prod=app&new=/194/216/JBUeCIHV4s394vYk3nbgt2.mp4";
NSString *const downloadURL2 = @"http://down.sandai.net/thunderspeed/ThunderSpeed1.0.34.360.exe";
NSString *const downloadURL3 = @"http://down.sandai.net/XLNetAcc/XLNetAccSetup.exe";

NSString *const imageURL1 = @"http://img.ivsky.com/img/bizhi/pre/201609/24/keaigougougaoqingtupianbizhi2.jpg";
NSString *const imageURL2 = @"http://desk.fd.zol-img.com.cn/t_s1600x900c5/g5/M00/0F/06/ChMkJlfI162IeK07AAY_egKaTWoAAU6qQHhDUcABj-S342.jpg?downfile=1475999712902.jpg";
NSString *const imageURL3 = @"http://static.zoommyapp.com/full/58580.jpg";

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *myTextView;
@property (nonatomic, strong) NSURLSessionTask *task;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.myTextView.text = nil;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions
- (IBAction)fetchDataAction:(id)sender {
    self.myTextView.text = nil;
    [self fetchData];
    //[self downloadFile];
    //[self syncGCD];
}

- (IBAction)cancelRequest:(id)sender {
    //[[ZDNetworkHelper shareInstance] cancelTaskWithURL:downloadURL2];
    [self.task cancel];
}

#pragma mark -

- (void)fetchData {
    NSArray *urls = @[/*url1,*/ url2, url3];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_apply(urls.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            ZD_Log(@"第%zd次执行", i);
            __weak __typeof(&*self) weakSelf = self;
            [[ZDNetworkHelper shareInstance] requestWithURL:urls[i] params:nil httpMethod:HttpMethod_POST cachedResponse:^(id  _Nullable cachedResponse) {
                __strong __typeof(&*weakSelf) strongSelf = weakSelf;
                ZD_Log(@"\n\n%@\n\n%@", cachedResponse, [strongSelf stringWithJson:cachedResponse]);
            } progress:^(NSProgress * _Nonnull progress, CGFloat progressValue) {
                ZD_Log(@"完成进度: %f", (CGFloat)progress.completedUnitCount / progress.totalUnitCount);
            } success:^(id  _Nullable responseObject) {
                __strong __typeof(&*weakSelf) strongSelf = weakSelf;
                strongSelf.myTextView.text = [strongSelf stringWithJson:responseObject];
                ZD_Log(@"\n\n%@\n\n%@", responseObject, [strongSelf stringWithJson:responseObject]);
            } failure:^(NSError * _Nonnull error) {
                ZD_Log(@"\nerror:%@", error.localizedDescription);
            }];
        });
    });
}

- (void)downloadFile {
    __weak __typeof(&*self)weakSelf = self;
    self.task = [[ZDNetworkHelper new] downloadWithURL:downloadURL2 saveToPath:nil progress:^(NSProgress * _Nonnull progress, CGFloat progressValue) {
        ZD_Log(@"下载进度 = %0.2f", progressValue);
    } success:^(id  _Nullable responseObject) {
        __strong __typeof(&*weakSelf)self = weakSelf;
        self.myTextView.text = responseObject;
        ZD_Log(@"下载完成的文件路径：%@", responseObject);
    } failure:^(NSError * _Nonnull error) {
        ZD_Log(@"错误信息 = %@", error);
    }];
}

//MARK:利用GCD notify同步线程
- (void)syncGCD {
    dispatch_queue_t queue1 = dispatch_queue_create("Myqueue1", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, queue1, ^{
        NSLog(@"睡眠2秒");
        sleep(2);
    });
    dispatch_group_async(group, queue1, ^{
        NSLog(@"睡眠5秒");
        sleep(5);
    });
    
    dispatch_group_notify(group, queue1, ^{
        NSLog(@"执行完毕");
    });
}

#pragma mark - Private Method

- (NSString *)stringWithJson:(id)temps { //把字典和数组转换成json字符串
    if (!temps) return nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:temps
                                                       options:NSJSONWritingPrettyPrinted error:nil];
    NSString *strs = [[NSString alloc] initWithData:jsonData
                                           encoding:NSUTF8StringEncoding];
    return strs;
}



@end
