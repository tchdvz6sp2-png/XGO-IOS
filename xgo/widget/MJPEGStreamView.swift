//
//  MJPEGStreamView.swift
//  xgo
//
//  MJPEG stream decoder and display view
//  Connects to CM4 video stream on port 5001
//

import UIKit

/// UIImageView subclass that displays a live MJPEG stream
class MJPEGStreamView: UIImageView, URLSessionDataDelegate {
    
    private var dataTask: URLSessionDataTask?
    private var session: URLSession?
    private var buffer = Data()
    
    /// Stream state
    enum StreamState {
        case stopped
        case loading
        case playing
        case error(String)
    }
    
    private(set) var streamState: StreamState = .stopped
    var onStateChanged: ((StreamState) -> Void)?
    
    // JPEG markers
    private let jpegStart: Data = Data([0xFF, 0xD8])
    private let jpegEnd: Data = Data([0xFF, 0xD9])
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        contentMode = .scaleAspectFit
        backgroundColor = .black
        clipsToBounds = true
    }
    
    // MARK: - Stream Control
    
    func startStream(url: URL) {
        stopStream()
        
        streamState = .loading
        onStateChanged?(.loading)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
    }
    
    func stopStream() {
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        buffer = Data()
        streamState = .stopped
        onStateChanged?(.stopped)
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // MJPEG stream returns multipart/x-mixed-replace
        streamState = .playing
        onStateChanged?(.playing)
        buffer = Data()
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        // Look for complete JPEG frames in buffer
        while let frame = extractJPEGFrame() {
            if let uiImage = UIImage(data: frame) {
                self.image = uiImage
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            // Don't report cancelled errors
            if nsError.code != NSURLErrorCancelled {
                streamState = .error(error.localizedDescription)
                onStateChanged?(.error(error.localizedDescription))
            }
        } else {
            streamState = .stopped
            onStateChanged?(.stopped)
        }
    }
    
    // MARK: - JPEG Frame Extraction
    
    private func extractJPEGFrame() -> Data? {
        // Find JPEG start marker (0xFF 0xD8)
        guard let startRange = buffer.range(of: jpegStart) else {
            return nil
        }
        
        // Find JPEG end marker (0xFF 0xD9) after the start
        let searchRange = startRange.lowerBound..<buffer.endIndex
        guard let endRange = buffer.range(of: jpegEnd, options: [], in: searchRange) else {
            return nil
        }
        
        // Extract the complete JPEG frame
        let frameRange = startRange.lowerBound..<endRange.upperBound
        let frame = buffer.subdata(in: frameRange)
        
        // Remove processed data from buffer
        buffer.removeSubrange(buffer.startIndex..<endRange.upperBound)
        
        return frame
    }
    
    deinit {
        stopStream()
    }
}
