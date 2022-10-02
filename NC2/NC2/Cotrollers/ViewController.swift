//
//  ViewController.swift
//  NC2
//
//  Created by kwon ji won on 2022/08/30.
//

import UIKit
import Vision
import AVFoundation
import ImageIO

class ViewController: UIViewController {
    @IBOutlet weak var selectimageview: UIImageView!
    @IBOutlet weak var photo: UIButton!
    @IBOutlet weak var camera: UIButton!
    @IBOutlet weak var caculateButton: UIButton!
    @IBOutlet weak var resultLabel: UILabel!
    private var bodyHeight : CGFloat = 0.0
//    {
//        get {
//            return self.bodyHeight
//        }
//        set(value) {
//
//        }
//    }
    
    
    private var faceHeight : CGFloat = 0.0
    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        DispatchQueue.main.async {
            self.present(ac, animated: true, completion: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    @IBAction func openPhoto(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }
    
    @IBAction func openCamera(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        present(imagePicker, animated: true)
    }
    
    @IBAction func caculate(_ sender: Any) {
        let ratio = bodyHeight / faceHeight
//        String(format: "%1.f", ratio)
        resultLabel.text = "당신은 \(String(format: "%.1f", ratio))등신입니다."
//        "%.1f"
    }
    
    

    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private func start() {
        guard selectimageview != nil else { return }
        if let image = selectimageview.image {
            self.selectimageview.contentMode = .scaleAspectFit
//            self.selectimageview.imageOrientation = CGImagePropertyOrientation(image.imageOrientation)
            
            guard let cgImage = image.cgImage else { return }
            
            self.setupVision(image: cgImage)
        }
    }
    
    private func setupVision(image: CGImage) {
        
        let humanbodyDectRequest = VNDetectHumanRectanglesRequest(completionHandler: self.handleHumanRectangleDetectionRequest)
        humanbodyDectRequest.upperBodyOnly = false
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleFaceDetectionRequest)
        let imageRequestHandler1 = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let imageRequestHandler2 = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        
        do {
            try imageRequestHandler1.perform([humanbodyDectRequest])
            try imageRequestHandler2.perform([faceDetectionRequest])
        } catch let error as NSError {
            print(error)
            return
        }
    }
    
    private func handleHumanRectangleDetectionRequest(request: VNRequest?, error: Error?) {
        if let requestError = error as NSError? {
            print(requestError)
            return
        }
        guard let image = selectimageview.image else { return }
        guard let cgImage = image.cgImage else { return }
        
        let imageRect = self.determineScale(cgImage: cgImage, imageViewFrame: selectimageview.frame)
        
        if let results = request?.results as? [VNHumanObservation] {
            for observation in results {
                let bodyRect = convertUnitToPoint(originalImageRect: imageRect, targetRect: observation.boundingBox)
                let view = UIView()
                let boxsize = CGRect(
                    x: bodyRect.origin.x ,
                    y: bodyRect.origin.y ,
                    width: bodyRect.size.width + 5,
                    height: bodyRect.size.height
                )
                
                self.bodyHeight = boxsize.height
//                print(bodyHeight)
//                print(self.bodyHeight)
                view.frame = boxsize
                view.layer.borderColor = UIColor.yellow.cgColor
                view.layer.borderWidth = 2
                self.selectimageview.addSubview(view)

            }
        }
    }
    
    private func handleFaceDetectionRequest(request: VNRequest?, error: Error?) {
        if let requestError = error as NSError? {
            print(requestError)
            return
        }
        
        guard let image = selectimageview.image else { return }
        guard let cgImage = image.cgImage else { return }
        
        let imageRext = self.determineScale(cgImage: cgImage, imageViewFrame: selectimageview.frame)
        
        if let results = request?.results as? [VNFaceObservation] {
            for observation in results {
                let faceRect = convertUnitToPoint(originalImageRect: imageRext, targetRect: observation.boundingBox)
                let view = UIView()
                let boxsize = CGRect(
                    x: faceRect.origin.x,
                    y: faceRect.origin.y - 7,
                    width: faceRect.size.width * 1.1,
                    height: faceRect.size.height * 1.7
                )
                view.frame = boxsize
                view.layer.borderColor = UIColor.red.cgColor
                view.layer.borderWidth = 2
                self.selectimageview.addSubview(view)
                self.faceHeight = boxsize.height
            }
        }
    }
    

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            self.selectimageview.image = image
            self.start()
        }
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("CANCEL!!")
        dismiss(animated: true)
    }
}

