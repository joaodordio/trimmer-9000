//
//  ViewController.swift
//  Trimmer 9000
//
//  Created by Joao Dordio on 15/09/2022.
//

import UIKit
import AVKit
import PhotosUI

class ViewController: UIViewController, PHPickerViewControllerDelegate {
                                  
    var startTime: CMTime = .zero
    var endTime: CMTime = .zero
    
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var thumbnailsView: UIStackView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var loadVideoButton: UIButton!
    
    var player: AVPlayer? {
      didSet {
        guard let duration = player?.currentItem?.duration else { return }
        endTime = duration
      }
    }
    
    var isPlaying: Bool = false
    
    var isVideoLoaded: Bool {
        get {
            return self.player?.currentItem != nil
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
    }
    
    private func configureViews() {
        loadVideoButton.isEnabled = !isVideoLoaded
        playButton.isEnabled = isVideoLoaded
        playButton.setImage(UIImage(systemName: "pause.circle"), for: .normal)
        playButton.imageView?.frame.size = CGSize(width: 50, height: 50)
        playButton.frame.size = CGSize(width: 50, height: 50)
    }
    
    // MARK: - Actions
    
    @IBAction func playPauseVideo(_ sender: Any) {
        isPlaying ? player?.pause() : player?.play()
        isPlaying.toggle()
        playButton.setImage(isPlaying ? UIImage(systemName: "pause.circle") : UIImage(systemName: "play.circle"), for: .normal)
    }
    
    /// Configures and presents a PHPickerViewController
    @IBAction func pickVideo(_ sender: Any) {
        
        // Setup the new PhotosKit picker configuration
        var videoPickerConfig = PHPickerConfiguration()
        videoPickerConfig.filter = .videos // we just want to pick up videos
        
        // this .compatible option takes more time to render the file, but it's best for the sake of the exercise.
        // by choosing .current we would get an HDR version of a video i.e. and we are not handling that rn.
        videoPickerConfig.preferredAssetRepresentationMode = .compatible
        
        // This viewcontroller is completley managed by iOS. We don't need to worry about its lifecycle.
        let videoPicker = PHPickerViewController(configuration: videoPickerConfig)
        videoPicker.delegate = self
        present(videoPicker, animated: true)
    }
    
    // MARK: - Functions
    
    /// Initializes the AVPlayer object, loads the selected video, and starts playback.
    private func loadVideo(videoURL: URL) {
        self.player = AVPlayer(url: videoURL)
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = playerView.layer.bounds
        playerLayer.videoGravity = .resizeAspect
        
        playerView.layer.addSublayer(playerLayer)
        self.player?.play()
        isPlaying.toggle()
        playButton.isEnabled.toggle()
    }
    
    private func generateThumbnails(for videoUrl: URL) {
        let video = AVURLAsset(url: videoUrl)
        let imageGenerator = AVAssetImageGenerator(asset: video)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.apertureMode = .encodedPixels
        
        
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: getIntervals(for: video.duration.seconds), completionHandler: { (time, thumbnailImage, secondTime, result, error) in
            defer {
                DispatchQueue.main.async {
                    self.thumbnailsView.layoutSubviews()
                }
            }
            
            DispatchQueue.main.async {
                let thumbnailImageView = UIImageView(image: UIImage(cgImage: thumbnailImage!))
                thumbnailImageView.frame.size = CGSize(width: self.thumbnailsView.frame.size.width / CGFloat(10), height: 50)
                
                
                self.thumbnailsView.addArrangedSubview(thumbnailImageView)
            }
        })
    }
    
    private func getIntervals(for duration: Double) -> [ NSValue ] {
        var intervals: [ NSValue ] = []
        for interval in (0...Int(duration.rounded())) {
            intervals.append(CMTime(seconds: Double(interval), preferredTimescale: 60) as NSValue)
        }
        
        return intervals
    }
    
    // MARK: - PHPickerViewController Delegate methods
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider else {
            print("No video was selected")
            return
        }
        
        // for the sake of the experiment we are loading the video in place.
        // for a fully fledged app, we would want to save a copy into the Documents folder.
        provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (url, finished, error) in
            guard let videoURL = url else { return }
            
            DispatchQueue.main.async {
                self.loadVideo(videoURL: videoURL)
                self.generateThumbnails(for: videoURL)
                self.loadVideoButton.isEnabled = false
            }
        }
    }
    
}

