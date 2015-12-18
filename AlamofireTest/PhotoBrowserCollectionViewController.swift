//
//  FirstViewController.swift
//  AlamofireTest
//
//  Created by niuwei on 15/12/17.
//  Copyright © 2015年 Sina. All rights reserved.
//

import UIKit
import Alamofire


class PhotoBrowserCollectionViewController:
    UICollectionViewController, UICollectionViewDelegateFlowLayout {

    var photos = NSMutableOrderedSet()
    
    let refreshControl = UIRefreshControl()
    
    var populatingPhotos = false
    var currentPage = 1
    
    let PhotoBrowserCellIdentifier = "PhotoBrowserCell"
    let PhotoBrowserFooterViewIdentifier = "PhotoBrowserFooterView"
    
    // MARK: Life-cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        populatePhotos()
        
//        Alamofire.request(.GET, "https://api.500px.com/v1/photos", parameters: ["consumer_key": "ucxNX0lYwbSHQBsMuyPCBGsa7RykTz9H6dHXCSVc"]).responseJSON() { response in
//            print(response.result.value)
//
//            if let data = response.result.value {
//                
//                let photoInfos = (data.valueForKey("photos") as! [NSDictionary]).filter({
//                    ($0["nsfw"] as! Bool) == false
//                }).map {
//                    PhotoInfo(id: $0["id"] as! Int, url: $0["image_url"] as! String)
//                }
//                
//                self.photos.addObjectsFromArray(photoInfos)
//                self.collectionView!.reloadData()
//            }
//        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: CollectionView
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoBrowserCellIdentifier, forIndexPath: indexPath) as! PhotoBrowserCollectionViewCell
        
        let imageURL = (photos.objectAtIndex(indexPath.row) as! PhotoInfo).url
        
        Alamofire.request(.GET, imageURL).response() {
            (_, _, data, _) in
            
            let image = UIImage(data: data! as NSData)
            cell.imageView.image = image
        }
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: PhotoBrowserFooterViewIdentifier, forIndexPath: indexPath) 
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        performSegueWithIdentifier("ShowPhoto", sender: (self.photos.objectAtIndex(indexPath.item) as! PhotoInfo).id)
    }
    
    // MARK: Helper
    
    func setupView() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        let layout = UICollectionViewFlowLayout()
        let itemWidth = (view.bounds.size.width - 2) / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = 1.0
        layout.minimumLineSpacing = 1.0
        layout.footerReferenceSize = CGSize(width: collectionView!.bounds.size.width, height: 100.0)
        
        collectionView!.collectionViewLayout = layout
        
        navigationItem.title = "Featured"
        
        collectionView!.registerClass(PhotoBrowserCollectionViewCell.classForCoder(), forCellWithReuseIdentifier: PhotoBrowserCellIdentifier)
        collectionView!.registerClass(PhotoBrowserCollectionViewLoadingCell.classForCoder(), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: PhotoBrowserFooterViewIdentifier)
        
        refreshControl.tintColor = UIColor.whiteColor()
        refreshControl.addTarget(self, action: "handleRefresh", forControlEvents: .ValueChanged)
        collectionView!.addSubview(refreshControl)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowPhoto" {
            (segue.destinationViewController as! PhotoViewerViewController).photoID = sender!.integerValue
            (segue.destinationViewController as! PhotoViewerViewController).hidesBottomBarWhenPushed = true
        }
    }
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y + view.frame.size.height > scrollView.contentSize.height * 0.8 {
            populatePhotos()
        }
    }
    
    func populatePhotos() {
        if populatingPhotos {
            return
        }
        
        populatingPhotos = true
        
        Alamofire.request(Five100px.Router.PopularPhotos(self.currentPage)).validate().responseJSON() {
            response in
            
            // 已经收到全部数据
            let error = response.result.error;
            let data = response.result.value
            
            if error == nil {
                // 在主线程操作，找到 photos 项下的字典数组中，key为nsfw且value为false的
                // map对filter结果集合的每一个元素操作，我加上了返回值的类型
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                    let photoInfos: [PhotoInfo] = ((data as! NSDictionary).valueForKey("photos") as! [NSDictionary]).filter({ ($0["nsfw"] as! Bool) == false }).map {
                        PhotoInfo(id: $0["id"] as! Int, url: $0["image_url"] as! String)
                    }
                    
                    // 把结果加入到photos集合中
                    let lastItem = self.photos.count
                    self.photos.addObjectsFromArray(photoInfos)
                    
                    // 遍历新加入photos的元素，创建indexpaths集合，加入界面collectionView
                    let indexPaths = (lastItem..<self.photos.count).map { NSIndexPath(forItem: $0, inSection: 0) }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.collectionView!.insertItemsAtIndexPaths(indexPaths)
                    }
                    
                    self.currentPage++
                }
            } else {
                print("Have you set your consumer key? Error: \(error!)")
            }
            
            self.populatingPhotos = false
        }
    }
    
    func handleRefresh() {
        
    }
}

class PhotoBrowserCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        imageView.frame = bounds
        addSubview(imageView)
    }
}

class PhotoBrowserCollectionViewLoadingCell: UICollectionReusableView {
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        spinner.startAnimating()
        spinner.center = self.center
        addSubview(spinner)
    }
}




