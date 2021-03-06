//
//  TRON.swift
//  TRON
//
//  Created by Denys Telezhkin on 28.01.16.
//  Copyright © 2015 - present MLSDev. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import Alamofire

/**
 `TRON` is a root object, that serves as a provider for single API endpoint. It is used to create and configure instances of `APIRequest` and `MultipartAPIRequest`.
 
 You need to hold strong reference to `TRON` instance while your network requests are running.
 */
public class TRON : TronDelegate {
    
    /// Header builder to be used by default in all requests. Can be overridden for specific requests.
    public var headerBuilder : HeaderBuildable = HeaderBuilder(defaultHeaders: ["Accept":"application/json"])
    
    /// NSURL builder to be used by default in all requests. Can be overridden for specific requests.
    public var urlBuilder : NSURLBuildable
    
    /// Global property, that defines whether stubbing is enabled. It is simply set on each `APIRequest` instance and can be reset.
    public var stubbingEnabled = false
    
    /// Global plugins, that will receive events from all requests, created from current TRON instance.
    public var plugins : [Plugin] = []
    
    /// Queue, used for processing response, received from the server. Defaults to QOS_CLASS_USER_INITIATED queue
    public var processingQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    
    /// Queue, used to deliver result completion blocks. Defaults to dispatch_get_main_queue().
    public var resultDeliveryQueue = dispatch_get_main_queue()
    
    /// Alamofire.Manager instance used to send network requests
    public let manager : Alamofire.Manager
    
    /**
     Initializes `TRON` with given base URL, Alamofire.Manager instance, and array of global plugins.
     
     - parameter baseURL: Base URL to be used 
     
     - parameter manager: Alamofire.Manager instance that will send requests created by current `TRON`
     
     - parameter plugins: Array of plugins, that will receive events from requests, created and managed by current `TRON` instance.
     */
    public init(baseURL: String,
        manager: Alamofire.Manager = TRON.defaultAlamofireManager(),
        plugins : [Plugin] = [])
    {
        self.urlBuilder = URLBuilder(baseURL: baseURL)
        self.plugins = plugins
        self.manager = manager
    }
    
    /**
     Creates APIRequest with specified relative path and type RequestType.Default.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - returns: APIRequest instance.
     */
    public func request<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String) -> APIRequest<Model,ErrorModel> {
        return APIRequest(type: .Default,path: path, tron: self)
    }
    
    /**
     Creates APIRequest with specified relative path and type RequestType.UploadFromFile.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - parameter file: File url to upload from.
     
     - returns: APIRequest instance.
     */
    public func upload<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String, file: NSURL) -> APIRequest<Model,ErrorModel> {
        return APIRequest(type: RequestType.UploadFromFile(file), path: path, tron: self)
    }
    
    /**
     Creates APIRequest with specified relative path and type RequestType.UploadData.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - parameter data: Data to upload.
     
     - returns: APIRequest instance.
     */
    public func upload<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String, data: NSData) -> APIRequest<Model,ErrorModel> {
        return APIRequest(type: RequestType.UploadData(data), path: path, tron: self)
    }
    
    /**
     Creates APIRequest with specified relative path and type RequestType.UploadStream.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - parameter stream: Stream to upload from.
     
     - returns: APIRequest instance.
     */
    public func upload<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String, stream: NSInputStream) -> APIRequest<Model,ErrorModel> {
        return APIRequest(type: RequestType.UploadStream(stream), path: path, tron: self)
    }
    
    /**
     Creates MultipartAPIRequest with specified relative path.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - parameter formData: Multipart form data creation block.
     
     - returns: MultipartAPIRequest instance.
     */
    public func uploadMultipart<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String, formData: MultipartFormData -> Void) -> MultipartAPIRequest<Model,ErrorModel> {
        return MultipartAPIRequest(path: path, tron: self, multipartFormData: formData)
    }
    
    /**
     Creates APIRequest with specified relative path and type RequestType.Download.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - parameter destination: Destination to download to.
     
     - returns: APIRequest instance.
     
     - seealso: `Alamofire.Request.suggestedDownloadDestination(directory:domain:)` method.
     */
    public func download<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String, destination: Request.DownloadFileDestination) -> APIRequest<Model,ErrorModel> {
        return APIRequest(type: RequestType.Download(destination), path: path, tron: self)
    }
    
    /**
     Creates APIRequest with specified relative path and type RequestType.DownloadResuming.
     
     - parameter path: Path, that will be appended to current `baseURL`.
     
     - parameter destination: Destination to download to.
     
     - parameter resumingFromData: Resume data for current request.
     
     - returns: APIRequest instance.
     
     - seealso: `Alamofire.Request.suggestedDownloadDestination(directory:domain:)` method.
     */
    public func download<Model:ResponseParseable, ErrorModel:ResponseParseable>(path path: String, destination: Request.DownloadFileDestination, resumingFromData: NSData) -> APIRequest<Model,ErrorModel> {
        return APIRequest(type: RequestType.DownloadResuming(data: resumingFromData, destination: destination), path: path, tron: self)
    }
    
    /**
     Default Alamofire.Manager instance to be used by `TRON`.
     
     - returns Alamofire.Manager instance initialized with NSURLSessionConfiguration.defaultSessionConfiguration().
     */
    public final class func defaultAlamofireManager() -> Manager {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders
        let manager = Manager(configuration: configuration)
        return manager
    }
}
