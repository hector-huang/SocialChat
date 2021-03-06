//
//  SubscriptionCell.swift
//  SocialChat
//
//  Created by ZhangJeff on 11/10/2016.
//  Copyright © 2016 Social Media Coders. All rights reserved.
//

import UIKit


class SubscriptionCell: UITableViewCell {

    @IBOutlet weak var channelName: UILabel!
    @IBOutlet weak var channelImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    func updateCell(index: Int){
        
        var i = 0
        for channel in subscriptionSet{
            if i == index{
                self.channelName.text = channel
                self.channelImage.image = UIImage(named: "\(channel).jpg")
                break
            }
            else{
                i += 1
            }
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
