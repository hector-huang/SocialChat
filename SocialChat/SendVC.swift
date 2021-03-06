//
//  SendVC.swift
//  SocialChat
//
//  Created by ZhangJeff on 29/09/2016.
//  Copyright © 2016 Social Media Coders. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import SDWebImage


class SendVC: JSQMessagesViewController{
    
    var messageRef: FIRDatabaseReference!
    var messages = [JSQMessage]()
    var outgoingBubbleImageView: JSQMessagesBubbleImage!
    var incomingBubbleImageView: JSQMessagesBubbleImage!
    
    private var _receiverId: String!
    private var _receiverName: String!
    private var imageUrl: String?

    var receiverId: String{
        get{
            return _receiverId
        }
        
        set{
            _receiverId = newValue
        }
    }
    
    var recieverName: String{
        get{
            return _receiverName
        }
        set{
            _receiverName = newValue
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if NetworkService.isInternetAvailable() == false{
            let alert = UIAlertController(title: "Network Error", message: "Please check your network connection.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
        
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        let currentUser = FIRAuth.auth()?.currentUser
        self.senderId = currentUser?.uid
        
        self.title = recieverName
        //set default value unless error
        self.senderDisplayName = ""
        observeUsers()
        setupBubbles()
        newobserveMessages()
    }
    
    
    // get DisplayName
    private func observeUsers(){
        DataService.instance.usersRef.child(self.senderId).child("profile").observeSingleEvent(of: .value, with: {(snapshot) in
            if let value = snapshot.value as? Dictionary<String, Any>{
                let username = value["username"]
                let senderImageUrl = value["imageUrl"]
                self.imageUrl = senderImageUrl as? String
                self.senderDisplayName = username as? String
            } else{
                print("error displayname")
                self.senderDisplayName = "error"
            }}) { (error) in
                print(error.localizedDescription)
        }
        
    }
    
    // Avatar not used now
//    private func observeUsers(){
//        DataService.instance.usersRef.child(self.senderId).child("profile").observeSingleEvent(of: .value, with: {(snapshot) in
//            if let value = snapshot.value as? Dictionary<String, Any>{
//                let username = value["username"]
//                self.senderDisplayName = username as? String
//                do{
//                    let imageUrl = value["imageUrl"] as! String
//                    let url = URL(string: imageUrl)
//                    let data = try Data(contentsOf: url!)
//                    let picture = UIImage(data: data)
//                    self.senderAvatar = JSQMessagesAvatarImageFactory.avatarImage(with: picture, diameter: 30)
//                    
//                } catch{
//                    print(error.localizedDescription)
//                }
//                
//            } else{
//                print("error displayname")
//                self.senderDisplayName = "error"
//            }}) { (error) in
//                print(error.localizedDescription)
//        }
//
//    }
    
    
    private func newobserveMessages(){
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YY-MM-dd 'at' HH:mm:ss"
        
        let senderQuery = DataService.instance.usersRef.child(senderId).child("sentMessage").queryOrdered(byChild: "receiverId").queryEqual(toValue: self.receiverId)
        
        senderQuery.observe(.childAdded) { (snapshot: FIRDataSnapshot!) in
            
            if let value = snapshot.value as? Dictionary<String, Any>{
                let contentType = value["contentType"] as! String
                let senderId = value["senderId"] as! String
                let senderName = value["senderName"] as! String
                let messageKey = snapshot.key
                let sendTime = dateFormatter.date(from: value["sentTime"] as! String)
                
                if contentType == "TEXT" {
                    let text = value["content"] as! String
                    self.messages.append(JSQMessage(senderId: senderId, senderDisplayName: senderName, date: sendTime,text: text))
                    self.finishReceivingMessage()
                    
                } else if contentType == "PHOTO" {
                        let imageUrl = value["content"] as! String
                        let url = URL(string: imageUrl)
                        let downloader = SDWebImageDownloader.shared()
                       _ = downloader?.downloadImage(with: url, options: [], progress: nil, completed: {
                        (image,data,error,finished) in
                        DispatchQueue.main.async {
                            let picture = image
                            let photo = JSQPhotoMediaItem(image: picture)
                            self.messages.append(JSQMessage(senderId: senderId, senderDisplayName: senderName, date: sendTime, media: photo))
                            self.finishReceivingMessage()
                        }
                    })
        
                } else if contentType == "VISIIMAGE"{
                    
                    let imageUrl = value["content"] as! String
                    let url = URL(string: imageUrl)
                    var visibleTime:String?
                    //old value in Database is Int
                    if let time = value["visibleTime"] as? Int{
                        visibleTime = String(time)
                    }
                    if let time = value["visibleTime"] as? String{
                        visibleTime = time
                    }
                        let downloader = SDWebImageDownloader.shared()
                       _ = downloader?.downloadImage(with: url, options: [], progress: nil, completed: {
                            (image,data,error,finished) in
                            DispatchQueue.main.async {
                                let picture = image
//                                picture = Util.rotateImage(image: picture!)
                                let photo = JSQVisibleMediaItem(image: picture, visibleTime: visibleTime, replayedTime: 0, messageKey: messageKey)
                                self.messages.append(JSQMessage(senderId: senderId, senderDisplayName: senderName, date: sendTime, media: photo))
                                self.finishReceivingMessage()
                            }
                        })
                    }
            }
            
        }
        
        let receiverQuery = DataService.instance.usersRef.child(senderId).child("receivedMessage").queryOrdered(byChild: "senderId").queryEqual(toValue: self.receiverId)
        
        receiverQuery.observe(.childAdded) { (snapshot: FIRDataSnapshot!) in
            
            if let value = snapshot.value as? Dictionary<String, Any>{
                let contentType = value["contentType"] as! String
                let senderId = value["senderId"] as! String
                let messageKey = snapshot.key
                let senderName = value["senderName"] as! String
                let receivedTime = dateFormatter.date(from: value["ReceivedTime"] as! String)
                if contentType == "TEXT" {
                    let text = value["content"] as! String
                    self.messages.append(JSQMessage(senderId: senderId, senderDisplayName: senderName, date: receivedTime, text: text))
                    self.finishReceivingMessage()
                }
                    else if contentType == "PHOTO" {
                        let imageUrl = value["content"] as! String
                        let url = URL(string: imageUrl)
                        let downloader = SDWebImageDownloader.shared()
                       _ = downloader?.downloadImage(with: url, options: [], progress: nil, completed: {
                            (image,data,error,finished) in
                            DispatchQueue.main.async {
                                let picture = image
                                let photo = JSQPhotoMediaItem(image: picture)
                                photo?.appliesMediaViewMaskAsOutgoing = false
                                self.messages.append(JSQMessage(senderId: senderId, senderDisplayName: senderName, date: receivedTime, media: photo))
                                self.finishReceivingMessage()
                        }
                    })
                } else if contentType == "VISIIMAGE"{
                    
                    var visibleTime:String?
                    //old value in Database is Int
                    if let time = value["visibleTime"] as? Int{
                        visibleTime = String(time)
                    }
                    if let time = value["visibleTime"] as? String{
                        visibleTime = time
                    }
                    
                    let imageUrl = value["content"] as! String
                    let url = URL(string: imageUrl)
                    let downloader = SDWebImageDownloader.shared()
                    _ = downloader?.downloadImage(with: url, options: [], progress: nil, completed: {
                            (image,data,error,finished) in
                        DispatchQueue.main.async {
                            let picture = image
//                            picture = Util.rotateImage(image: picture!)
                            let photo = JSQVisibleMediaItem(image: picture, visibleTime: visibleTime, replayedTime: 0, messageKey: messageKey)
                            self.messages.append(JSQMessage(senderId: senderId, senderDisplayName: senderName, date: receivedTime, media: photo))
                            self.finishReceivingMessage()
                        }
                    })
                }
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    
    private func setupBubbles(){
        let factory = JSQMessagesBubbleImageFactory()!
        outgoingBubbleImageView = factory.outgoingMessagesBubbleImage(
            with: UIColor.jsq_messageBubbleBlue())
        incomingBubbleImageView = factory.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        
        if message.senderId == senderId{
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    // profile image add later!!!!!!!!!!
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
//        let message = messages[indexPath.row]
//        if message.senderId == senderId{
//            return senderAvatar
//        } else{
//            return nil
//        }
        return nil
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? NormalImageVC{
            if let image = sender as? UIImage{
                destination.image = image
            }
        }
        if let destination = segue.destination as? PresentImageVC{
            if let item = sender as? JSQVisibleMediaItem{
                let visibleTime = item.visibleTime
                let item:Dictionary<String, Any> = ["visibleTime":visibleTime!,"visibleImage":item.image]
                destination.items = item
            }
        }
    }
    
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        let message = messages[indexPath.item]
        if message.isMediaMessage{
            if let mediaItem = message.media as? JSQPhotoMediaItem {
                performSegue(withIdentifier: "NormalImageVC", sender: mediaItem.image)
            }
            if let mediaItem = message.media as? JSQVisibleMediaItem {
                performSegue(withIdentifier: "PresentImageVC", sender: mediaItem)
                
                // receiver can only watch twice
                if message.senderId != myId!{
                    mediaItem.addreplayedTime()
                    if mediaItem.replayedTime == 2{
                        messages.remove(at: indexPath.item)
                        DataService.instance.selfRef.child("receivedMessage").child(mediaItem.messageKey).setValue(nil)
                        collectionView.reloadData()
                    }
                }
            }
        }
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        DataService.instance.sendMessage(messageType: "TEXT", content: text, senderId: senderId, senderName: senderDisplayName, receiverId: self.receiverId, receiverName: self.recieverName, senderImageUrl: self.imageUrl!)

        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        photoLibrary()
    }
    
    
    func photoLibrary(){
        let myPickerController = UIImagePickerController()
        myPickerController.delegate = self
        myPickerController.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(myPickerController, animated: true, completion: nil)
    }
    
    func sendMedia(picture: UIImage) {
       
            let filePath = "\(senderId!)/\(Date.timeIntervalSinceReferenceDate)"
            let ref = DataService.instance.imageStorageRef.child(filePath)
            let data = UIImageJPEGRepresentation(picture, 0.5)
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpg"
            ref.put(data!, metadata: metadata) { (metadata, error) in
                if error != nil{
                    print(error?.localizedDescription)
                    return
                }
                let imageUrl = metadata!.downloadURLs![0].absoluteString
                DataService.instance.sendMessage(messageType: "PHOTO", content: imageUrl, senderId: self.senderId, senderName: self.senderDisplayName, receiverId: self.receiverId,receiverName: self.recieverName,senderImageUrl: self.imageUrl!)
                
                JSQSystemSoundPlayer.jsq_playMessageSentSound()
                self.finishSendingMessage()
            }
    }
    
    
    @IBAction func backButtonPressed(_ sender: AnyObject) {
        dismiss(animated: false, completion: nil)
    }
    
}

extension SendVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let picture = info[UIImagePickerControllerOriginalImage] as? UIImage {
            sendMedia(picture: picture)
        }
        
        self.dismiss(animated: true, completion: nil)
        finishSendingMessage()
    }
}
