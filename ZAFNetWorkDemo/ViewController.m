//
//  ViewController.m
//  ZAFNetWorkDemo
//
//  Created by apple on 14/12/17.
//  Copyright (c) 2014年 Saber. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *myTextView;

@end

@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

	[self test];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - ZAF test

- (void)test
{
	NSString *url1 = @"https://daka.facenano.com/checkin/v1/app_binding?phone_number=18700000001&app_version_code=2&device=mobile_ios&company_tag=iPhone-demo&phone_imei=6D56F277-0AAA-4F32-AD01-6C55AEE75964&verification_code=3216";

	NSString *url2 = @"http://api.douban.com/v2/movie/top250";

	NSString *url3 = @"http://10.255.223.149:80/media/api.go?action=getDepositShowView&fromPaltform=ds_ios&paymentId=1014&token=9047a07dc6153188b690c8c740cb84f1";

	__weak __typeof(* &self) weakSelf = self;

	[[ZAFNetWorkHelper shareInstance] requestWithURL:url3 params:nil httpMethod:@"GET" hasCertificate:NO sucess:^(id responseObject) {
		__strong __typeof(*&weakSelf) self = weakSelf;
		self.myTextView.text = [self stringWithJson:responseObject];
		NSLog(@"\n\n%@\n\n%@", responseObject, [self stringWithJson:responseObject]);
	} failure:^(NSError *error) {
		NSLog(@"\nerror:%@", error);
	}];
}

- (NSString *)stringWithJson:(id)temps //把字典和数组转换成json字符串
{
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:temps
		options:NSJSONWritingPrettyPrinted error:nil];
	NSString *strs = [[NSString alloc] initWithData:jsonData
		encoding:NSUTF8StringEncoding];

	return strs;
}

@end
