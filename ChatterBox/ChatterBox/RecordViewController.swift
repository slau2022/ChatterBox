//
//  LeftViewController.swift
//  ChatterBox
//
//  Created by Edward on 2/14/20.
//  Copyright © 2020 Edward. All rights reserved.
//

import UIKit
import AVFoundation
import Speech
import Alamofire
import SwiftyJSON

class RecordViewController: UIViewController, AVAudioRecorderDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    @IBOutlet var soundBars: [UIView]!
    @IBOutlet weak var recordButton: UIButton!
            
    let fileName = "record.m4a"
        
    var filemanager = FileManager.default
    var audioRecorder = AVAudioRecorder()
    var imagePicker =  UIImagePickerController()
    
    var picture: UIImage!
    var speech = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestTranscribePermissions()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
        }
        
        catch {
            print("could not set session category")
            print(error.localizedDescription)
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("could not make session active")
            print(error.localizedDescription)
        }
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey : 320000,
            AVNumberOfChannelsKey : 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let fileURL = getFileURL()
        if FileManager.default.fileExists(atPath: fileURL.absoluteString) {
            print("soundfile \(fileURL.absoluteString) exists")
        }
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.prepareToRecord()
        } catch {
            print("failed to make audioRecorder")
        }
        
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
    }
    
    func startRecording() {
        audioRecorder.record()
    }
    
    func finishRecording() {
        self.audioRecorder.stop()
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getFileURL() -> URL {
        let path = getDocumentsDirectory().appendingPathComponent(fileName)
        return path as URL
    }
    
    func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    print("Good to go!")
                } else {
                    print("Transcription permission was declined.")
                }
            }
        }
    }
    
    func transcribeAudio(url: URL) {
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        recognizer?.recognitionTask(with: request) { (result, error) in
            guard let result = result else {
                print("UH OH: \(error!)")
                self.dismiss(animated: false, completion: nil)
                return
            }

            if result.isFinal {
                self.present(self.imagePicker, animated: true)
                self.speech = result.bestTranscription.formattedString
                print(self.speech)
            }
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            picture = image
            imagePicker.dismiss(animated: true, completion: didFinishTakingPic)
        }
    }
    
    func didFinishTakingPic() {
        guard let image = picture else { return }
        
        let alertController = UIAlertController(title: "Type in person's name below!", message: "", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Name"
        }
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak alertController] _ in
            guard let alertController = alertController, let textField = alertController.textFields?.first else { return }
            
            let alert = UIAlertController(title: nil, message: "Hang on just a bit...", preferredStyle: .alert)
    
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = UIActivityIndicatorView.Style.medium
            loadingIndicator.startAnimating()
    
            alert.view.addSubview(loadingIndicator)
            self.present(alert, animated: true)
                    
            let imgData = image.jpegData(compressionQuality: 1.0)!
            
            let uploadURL = "https://chatterboxweb.herokuapp.com/enter"
            
            let parameters = ["user": Globals.name, "friend": textField.text!.capitalized, "conversation": self.speech]
            Alamofire.upload(
                multipartFormData: { multipartFormData in
                    for (key, value) in parameters {
                        multipartFormData.append(value.data(using: .utf8)!, withName: key)
                    }
                    multipartFormData.append(imgData, withName: "profilePicture", fileName: "profilePicture.jpeg", mimeType: "image/jpeg")
            }, to: uploadURL) { (result) in
                        switch result {
                        case .success(let upload, _, _):
                            upload.responseJSON { response in
                                switch response.result {
                                case .success(let value):
                                    let json = JSON(value)
                                    print("JSON: \(json)")
                                    self.dismiss(animated: false, completion: nil)
                                    let alert = UIAlertController(title: "Information Saved!", message: nil, preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))

                                    self.present(alert, animated: true)
                                case .failure(let error):
                                    print(error)
                                }
                            }
                        case .failure(let encodingError):
                            print(encodingError)
                        }
                    }
        }
        alertController.addAction(confirmAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }

    @IBAction func pressedRecord(_ sender: Any) {
        if !self.audioRecorder.isRecording {
            for bar in self.soundBars {
                bar.isHidden = false
            }
            UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
                for bar in self.soundBars {
                    bar.transform = CGAffineTransform(scaleX: 1, y: CGFloat.random(in: 0.2..<2.0))
                }
            }, completion: nil)
            startRecording()
        }
        else {
            for bar in self.soundBars {
                bar.isHidden = true
            }
            finishRecording()
            transcribeAudio(url: getFileURL())
        }
    }
}
