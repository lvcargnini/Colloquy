//  Created by August Joki on 1/19/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#if ENABLE(FILE_TRANSFERS)

@class MVFileTransfer;
@class CQFileTransferTableCell;

NS_ASSUME_NONNULL_BEGIN

@interface CQFileTransferController : UIViewController
@property (nonatomic, readonly) MVFileTransfer *transfer;
@property (nonatomic, assign) CQFileTransferTableCell *cell;
@property (nonatomic, readonly) BOOL thumbnailAvailable;

- (id) initWithTransfer:(MVFileTransfer *) transfer;
- (UIImage *) thumbnailWithSize:(CGSize) size;
@end

NS_ASSUME_NONNULL_END

#endif
