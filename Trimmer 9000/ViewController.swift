//
//  ViewController.swift
//  Trimmer 9000
//
//  Created by Joao Dordio on 15/09/2022.
//

import UIKit
import AVKit
import PhotosUI

class ViewController: UIViewController {
    
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var thumbnailsView: UIStackView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var loadCustomVideoButton: UIButton!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var cancelTrimButton: UIButton!
    @IBOutlet weak var trimButton: UIButton!
    
    let indicatorView = UIView()
    let trimmerView = UIView()
    let leftHandleView = TrimHandleView(orientation: .left)
    let rightHandleView = TrimHandleView(orientation: .right)
    
    let trimmedStartLabel = UILabel()
    let trimmedEndLabel = UILabel()
    
    var player: AVPlayer!
    var asset: AVAsset!
    var playerItem: AVPlayerItem!
    var isPlaying: Bool = false
    var isVideoLoaded: Bool {
        get {
            if let player = self.player {
                return player.currentItem != nil
            }
            return false
        }
    }
    
    var isTrimming: Bool = false
    
    var startTime: CMTime = .zero
    var endTime: CMTime = .zero
    
    var trimmedStart: CMTime = .zero
    var trimmedEnd: CMTime = .zero
    
    var timeObserverToken: Any?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
    }
    
    // MARK: - UI Actions
    // MARK: - Playback
    
    @IBAction func playPauseVideo(_ sender: Any) {
        isPlaying ? pause() : play()
    }
    
    @IBAction func restartVideo(_ sender: Any) {
        restart()
    }
    
    @IBAction func loadCustomVideo(_ sender: Any) {
        let customVideoURL = Bundle.main.url(forResource: "video", withExtension: "mov")!
        
        loadVideo(videoURL: customVideoURL)
    }
    
    // MARK: - Gestures
    
    @IBAction func userScrubbed(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        
        pause()
        
        let position = gestureRecognizer.location(in: thumbnailsView) // I'm using the thumbnailsView as a reference
        
        if gestureRecognizer.state == .changed || gestureRecognizer.state == .began {
            var x = position.x
            
            if x < 0 { x = 0 } // limit the scrub on the left bounds
            if x > thumbnailsView.frame.width - 4 { x = thumbnailsView.frame.width - 4 } // limit the scrub on the right bounds
            
            let newCenter = CGPoint(x: x, y: indicatorView.frame.origin.y) // just update the x coordinate to get an horizontal movement
            indicatorView.frame.origin = newCenter
            
            let timeToSeek = (x * endTime.seconds) / thumbnailsView.frame.width
            
            let time = CMTime(seconds: timeToSeek, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) // actual player scrubbing
        }
        else if gestureRecognizer.state == .ended {
            // I would update the playehead position at this time.
        }
    }
    
    @objc func trimLeft(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        
        let position = gestureRecognizer.location(in: thumbnailsView) // I'm using the thumbnailsView as a reference
        if gestureRecognizer.state == .changed || gestureRecognizer.state == .began {
            var x = position.x
            
            let handleOffset = CGFloat(40)
            
            if x < 0 { x = 0 } // limit the scrub on the left bounds
            if x > thumbnailsView.frame.width - handleOffset { x = thumbnailsView.frame.width - handleOffset } // limit the scrub on the right bounds.
            
            let newCenter = CGPoint(x: x, y: leftHandleView.frame.origin.y)
            
            let timeToSeek = (x * endTime.seconds) / thumbnailsView.frame.width
            
            trimmedStartLabel.isHidden = false // trimmed time label is made visible. could use some animation here
            trimmedStartLabel.frame.origin.x = x // its position updated
            
            trimmedStartLabel.text = String(format: "%.2fs", timeToSeek)
            leftHandleView.frame.origin = newCenter
            
            // update the value here for later usage when exporting
            trimmedStart = CMTime(seconds: timeToSeek, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        } else if gestureRecognizer.state == .ended {
            // this could be done with an animation block
            trimmedStartLabel.isHidden = true
        }
    }
    
    @objc func trimRight(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        
        let position = gestureRecognizer.location(in: thumbnailsView)
        if gestureRecognizer.state == .changed || gestureRecognizer.state == .began {
            
            let handleOffset = CGFloat(40)
            
            var x = position.x
            
            if x < 0 { x = 0 } // limit the scrub on the left bounds
            if x > thumbnailsView.frame.width - handleOffset { x = thumbnailsView.frame.width - handleOffset } // limit the scrub on the right bounds.
            
            let newCenter = CGPoint(x: x, y: rightHandleView.frame.origin.y)
            
            rightHandleView.frame.origin = newCenter
            
            let timeToSeek = (x * endTime.seconds) / thumbnailsView.frame.width
            
            trimmedEndLabel.isHidden = false // trimmed time label is made visible. could use some animation here
            trimmedEndLabel.frame.origin.x = x // its position updated
            trimmedEndLabel.text = String(format: "%.2fs", timeToSeek)
            
            // update the value here for later usage when exporting
            trimmedEnd = CMTime(seconds: timeToSeek, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        } else if gestureRecognizer.state == .ended {
            // this could be done with an animation block
            trimmedEndLabel.isHidden = true
        }
    }
    
    // MARK: - Trimmer
    
    @IBAction func enableTrimmer(_ sender: Any) {
        stop() // intentionally stop the playback
        
        //update views state
        isTrimming = true
        trimButton.isEnabled = false
        shareButton.isHidden = false
        cancelTrimButton.isHidden = false
        
        configureTrimmer()
    }
    
    @IBAction func cancelTrim(_ sender: Any) {
        //update views state
        isTrimming = false
        trimButton.isEnabled = true
        cancelTrimButton.isHidden = true
        shareButton.isHidden = true
        
        trimmerView.removeFromSuperview()
    }
    
    @IBAction func shareVideo(_ sender: Any) {
        guard let outputVideoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("trimmed.mov") else { return }
        
        // Ensure that no older file is present, which would prevent the new one to be saved.
        do {
            try FileManager.default.removeItem(at: outputVideoURL)
        } catch {
            print("Could not remove file \(error.localizedDescription)")
        }
        
        // create the new trimmed range
        let timeRange = CMTimeRangeFromTimeToTime(start: trimmedStart, end: trimmedEnd)
        
        // setup the export task
        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        
        exporter?.outputURL = outputVideoURL
        exporter?.outputFileType = .mov
        exporter?.timeRange = timeRange
        
        exporter?.exportAsynchronously {
            DispatchQueue.main.async {
                if let error = exporter?.error {
                    print("failed \(error.localizedDescription)")
                } else {
                    self.shareVideoFile(outputVideoURL) // calls the iOS Sharesheet
                }
            }
        }
    }
    
    // MARK: - Player Actions
    
    /// Starts playback of the player at the current position
    private func play() {
        
        // adjust the playhead to the trimmed position
        if isTrimming {
            player.seek(to: trimmedStart, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        player.play()
        isPlaying = true
        playButton.setImage(isPlaying ? UIImage(systemName: "pause.circle") : UIImage(systemName: "play.circle"), for: .normal)
    }
    
    /// Pauses the playback of the player
    private func pause() {
        player.pause()
        isPlaying = false
        playButton.setImage(isPlaying ? UIImage(systemName: "pause.circle") : UIImage(systemName: "play.circle"), for: .normal)
    }
    
    /// Restarts playback from the beginning
    private func restart() {
        player.seek(to: startTime, toleranceBefore: startTime, toleranceAfter: startTime)
    }
    
    // Stops player playback
    private func stop() {
        isPlaying = false
        player.pause()
        player.seek(to: isTrimming ? trimmedStart : startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        playButton.setImage(isPlaying ? UIImage(systemName: "pause.circle") : UIImage(systemName: "play.circle"), for: .normal)
    }
    
    // MARK: - Functions
    
    /// Sets initial UI state for all visible views.
    private func configureViews() {
        loadCustomVideoButton.isEnabled = !isVideoLoaded
        
        trimButton.isEnabled = false
        restartButton.isEnabled = false
        
        playButton.isEnabled = isVideoLoaded
        playButton.setImage(UIImage(systemName: "pause.circle"), for: .normal)
        
        cancelTrimButton.isHidden = true
        
        shareButton.isHidden = true
    }
    
    /// Initializes the AVPlayer object, loads the selected video, and starts playback.
    private func loadVideo(videoURL: URL) {
        asset = AVAsset(url: videoURL)
        playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable"])
        player = AVPlayer(playerItem: playerItem)
        
        // I need this to observe the current playback time of the player
        addPeriodicTimeObserver()
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = playerView.layer.bounds
        playerLayer.videoGravity = .resizeAspect // force the video to fit on the specified view
        
        playerView.layer.addSublayer(playerLayer)
        
        // registering for this notification to update the UI as soon as the player finishes playing.
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        // generate the thumbnails and when that's done, start the playback
        generateThumbnails(for: videoURL) {
            self.configureTimelineView()
            self.thumbnailsView.layoutSubviews()
            self.play()
        }
        
        // update UI state
        playButton.isEnabled.toggle()
        loadCustomVideoButton.isEnabled = false
        restartButton.isEnabled = true
        trimButton.isEnabled = true
    }
    
    /// Generates thumbnails for the player timeline
    private func generateThumbnails(for videoUrl: URL, completion: @escaping () -> Void = {}) {
        let video = AVURLAsset(url: videoUrl)
        
        let imageGenerator = AVAssetImageGenerator(asset: video)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.apertureMode = .encodedPixels
        
        endTime = video.duration
        var thumbnailsRemaining = video.duration.seconds.rounded()
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: getIntervals(for: video.duration.seconds), completionHandler: { (time, thumbnailImage, secondTime, result, error) in
            
            DispatchQueue.main.async {
                let thumbnailImageView = UIImageView(image: UIImage(cgImage: thumbnailImage!))
                thumbnailImageView.frame.size = CGSize(width: self.thumbnailsView.frame.size.width / CGFloat(10), height: 40)
                
                // I'm using an horizontal stackView to layout the images correctly
                self.thumbnailsView.addArrangedSubview(thumbnailImageView)
                
                // controll flow
                thumbnailsRemaining -= 1
                if thumbnailsRemaining <= 0 {
                    completion()
                }
            }
        })
    }
    
    /// Configures and adds the playhead view to the timeline view
    private func configureTimelineView() {
        indicatorView.frame = CGRect(x: 0, y: -2, width: 4, height: 55)
        indicatorView.backgroundColor = .white
        indicatorView.layer.cornerRadius = 2
        
        thumbnailsView.addSubview(indicatorView)
    }
    
    /// Configures the border, left and right handles of the trimming interface
    private func configureTrimmer() {
        trimmerView.frame = CGRect(x: 0, y: 0, width: thumbnailsView.frame.size.width, height: thumbnailsView.frame.size.height)
        trimmerView.backgroundColor = .clear
        trimmerView.layer.borderColor = UIColor.systemYellow.cgColor
        trimmerView.layer.borderWidth = 5
  
        rightHandleView.frame = CGRect(x: thumbnailsView.frame.size.width - 40, y: 0, width: 40, height: 50)
        
        let leftGesture = UIPanGestureRecognizer(target: self, action: #selector(trimLeft))
        leftHandleView.addGestureRecognizer(leftGesture)
        
        let rightGesture = UIPanGestureRecognizer(target: self, action: #selector(trimRight))
        rightHandleView.addGestureRecognizer(rightGesture)
        
        trimmerView.addSubview(leftHandleView)
        trimmerView.addSubview(rightHandleView)
        
        trimmedStartLabel.frame = CGRect(origin: CGPoint(x: 0, y: -20), size: CGSize(width: 100, height: 20))
        trimmedEndLabel.frame = CGRect(origin: CGPoint(x: trimmerView.frame.size.width, y: -20), size: CGSize(width: 100, height: 20))
        
        trimmedStartLabel.isHidden = true
        trimmedEndLabel.isHidden = true
        
        trimmerView.addSubview(trimmedStartLabel)
        trimmerView.addSubview(trimmedEndLabel)
        thumbnailsView.addSubview(trimmerView)
    }
    
    private func shareVideoFile(_ file: URL) {
        // Create the Array which includes the files you want to share
        var filesToShare = [Any]()
        
        // Add the path of the file to the Array
        filesToShare.append(file)
        
        // Make the activityViewContoller which shows the share-view
        let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)
        
        // Show the share-view
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    // MARK: - Observers
    
    /// Handle player UI to conform to current time
    private func addPeriodicTimeObserver() {
        // Notify every millisecond
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        
        let time = CMTime(seconds: 0.01, preferredTimescale: timeScale)
        let width = self.thumbnailsView.frame.width
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            // check if trimmer is enabled so we should stop playing after the trim end
            if self?.isTrimming ?? false,
               let trimmedEnd = self?.trimmedEnd,
               time >= trimmedEnd {
                self?.stop()
            }
            
            // Update the timecode label. In the future i would update this to look like: 00:00:00.00
            self?.currentTimeLabel.text = self?.getCurrentTimeString(time: time.seconds)
            
            if let duration = self?.endTime.seconds, duration > 0 {
                self?.indicatorView.frame.origin.x = (width * time.seconds) / duration
            }
        }
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        stop()
    }
    
    // MARK: - Helpers
    
    /// Creates an array of CMTime objects for every second of the duration of the video
    func getIntervals(for duration: Double) -> [ NSValue ] {
        var intervals: [ NSValue ] = []
        for interval in (0...Int(duration.rounded())) {
            intervals.append(CMTime(seconds: Double(interval), preferredTimescale: 60) as NSValue)
        }
        
        return intervals
    }
    
    func getCurrentTimeString(time: Double) -> String {
        let (hours, min, sec) = secondsToHoursMinutesSeconds(time)
        return String(format: "%.0f:%.0f:%.2f", hours, min, sec)
    }
    
    func secondsToHoursMinutesSeconds(_ seconds: Double) -> (Double, Double, Double) {
        return (seconds / 3600, (seconds.truncatingRemainder(dividingBy: 3600)) / 60, (seconds.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60)))
    }
}

