//
//  Five100px.swift
//  Photomania
//
//  Created by Essan Parto on 2014-09-25.
//  Copyright (c) 2014 Essan Parto. All rights reserved.
//

import UIKit
import Alamofire

extension Request {
    
    /**
     Creates a response serializer that returns a string initialized from the response data with the specified
     string encoding.
     
     - parameter encoding: The string encoding. If `nil`, the string encoding will be determined from the server
     response, falling back to the default HTTP default character set, ISO-8859-1.
     
     - returns: A string response serializer.
     */
    public static func stringResponseSerializer(
        var encoding encoding: NSStringEncoding? = nil)
        -> ResponseSerializer<String, NSError>
    {
        return ResponseSerializer { _, response, data, error in
            guard error == nil else { return .Failure(error!) }
            
            if let response = response where response.statusCode == 204 { return .Success("") }
            
            guard let validData = data else {
                let failureReason = "String could not be serialized. Input data was nil."
                let error = Error.errorWithCode(.StringSerializationFailed, failureReason: failureReason)
                return .Failure(error)
            }
            
            if let encodingName = response?.textEncodingName where encoding == nil {
                encoding = CFStringConvertEncodingToNSStringEncoding(
                    CFStringConvertIANACharSetNameToEncoding(encodingName)
                )
            }
            
            let actualEncoding = encoding ?? NSISOLatin1StringEncoding
            
            if let string = String(data: validData, encoding: actualEncoding) {
                return .Success(string)
            } else {
                let failureReason = "String could not be serialized with encoding: \(actualEncoding)"
                let error = Error.errorWithCode(.StringSerializationFailed, failureReason: failureReason)
                return .Failure(error)
            }
        }
    }
    
    /**
     Adds a handler to be called once the request has finished.
     
     - parameter encoding:          The string encoding. If `nil`, the string encoding will be determined from the
     server response, falling back to the default HTTP default character set,
     ISO-8859-1.
     - parameter completionHandler: A closure to be executed once the request has finished.
     
     - returns: The request.
     */
    public func responseString(
        encoding encoding: NSStringEncoding? = nil,
        completionHandler: Response<String, NSError> -> Void)
        -> Self
    {
        return response(
            responseSerializer: Request.stringResponseSerializer(encoding: encoding),
            completionHandler: completionHandler
        )
    }
}


extension Alamofire.Request {
    public static func imageResponseSerializer() -> ResponseSerializer<UIImage, NSError> {
        return ResponseSerializer { _, response, data, error in
            guard error == nil else { return .Failure(error!) }
            
            let defaultImage: UIImage = UIImage(named: "default_image")!;
            if let response = response where response.statusCode == 204 { return .Success(defaultImage) }
            
            guard nil == data else {
                let failureReason = "Image could not be serialized. Input data was nil."
                let error = Error.errorWithCode(.StringSerializationFailed, failureReason: failureReason)
                return .Failure(error)
            }
            
            let image = UIImage(data: data!, scale: UIScreen.mainScreen().scale)!
            return .Success(image)
        }
    }
    
    public func responseImage(
        //completionHandler: (NSURLRequest, NSHTTPURLResponse?, UIImage?, NSError?) -> Void) -> Self {
        completionHandler: Response<UIImage, NSError> -> Void) -> Self {
        return response(
            responseSerializer: Request.imageResponseSerializer(),
            completionHandler: completionHandler)
    }
}

struct Five100px {
    enum Router: URLRequestConvertible {
        static let baseURLString = "https://api.500px.com/v1"
        static let consumerKey = "ucxNX0lYwbSHQBsMuyPCBGsa7RykTz9H6dHXCSVc"
        
        case PopularPhotos(Int)
        case PhotoInfo(Int, ImageSize)
        case Comments(Int, Int)
        
        var URLRequest: NSMutableURLRequest {
            let closure = { () -> (path: String, parameters: [String: AnyObject]) in
                switch self {
                case .PopularPhotos (let page):
                    let params = ["consumer_key": Router.consumerKey, "page": "\(page)", "feature": "popular", "rpp": "50",  "include_store": "store_download", "include_states": "votes"]
                    return ("/photos", params)
                case .PhotoInfo(let photoID, let imageSize):
                    let params = ["consumer_key": Router.consumerKey, "image_size": "\(imageSize.rawValue)"]
                    return ("/photos/\(photoID)", params)
                case .Comments(let photoID, let commentsPage):
                    let params = ["consumer_key": Router.consumerKey, "comments": "1", "comments_page": "\(commentsPage)"]
                    return ("/photos/\(photoID)/comments", params)
                }
            }
            
            let (path, parameters) = closure()
            
            let URL = NSURL(string: Router.baseURLString)
            let URLRequest = NSMutableURLRequest(URL: URL!.URLByAppendingPathComponent(path))
            let encoding = Alamofire.ParameterEncoding.URL
            
            return encoding.encode(URLRequest, parameters: parameters).0
        }
    }
    
    enum ImageSize: Int {
        case Tiny = 1
        case Small = 2
        case Medium = 3
        case Large = 4
        case XLarge = 5
    }
}

class PhotoInfo: NSObject {
    let id: Int
    let url: String
    
    var name: String?
    
    var favoritesCount: Int?
    var votesCount: Int?
    var commentsCount: Int?
    
    var highest: Float?
    var pulse: Float?
    var views: Int?
    var camera: String?
    var desc: String?
    
    init(id: Int, url: String) {
        self.id = id
        self.url = url
    }
    
    required init(response: NSHTTPURLResponse, representation: AnyObject) {
        self.id = representation.valueForKeyPath("photo.id") as! Int
        self.url = representation.valueForKeyPath("photo.image_url") as! String
        
        self.favoritesCount = representation.valueForKeyPath("photo.favorites_count") as? Int
        self.votesCount = representation.valueForKeyPath("photo.votes_count") as? Int
        self.commentsCount = representation.valueForKeyPath("photo.comments_count") as? Int
        self.highest = representation.valueForKeyPath("photo.highest_rating") as? Float
        self.pulse = representation.valueForKeyPath("photo.rating") as? Float
        self.views = representation.valueForKeyPath("photo.times_viewed") as? Int
        self.camera = representation.valueForKeyPath("photo.camera") as? String
        self.desc = representation.valueForKeyPath("photo.description") as? String
        self.name = representation.valueForKeyPath("photo.name") as? String
    }
    
    override func isEqual(object: AnyObject!) -> Bool {
        return (object as! PhotoInfo).id == self.id
    }
    
    override var hash: Int {
        return (self as PhotoInfo).id
    }
}

class Comment {
    let userFullname: String
    let userPictureURL: String
    let commentBody: String
    
    init(JSON: AnyObject) {
        userFullname = JSON.valueForKeyPath("user.fullname") as! String
        userPictureURL = JSON.valueForKeyPath("user.userpic_url") as! String
        commentBody = JSON.valueForKeyPath("body") as! String
    }
}