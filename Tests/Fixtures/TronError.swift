//
//  TronError.swift
//  TRON
//
//  Created by Denys Telezhkin on 28.01.16.
//  Copyright © 2016 Denys Telezhkin. All rights reserved.
//

import Foundation
import TRON
import SwiftyJSON

class TronError : JSONDecodable, ResponseParseable {
    required init(json: JSON) {
    }
}