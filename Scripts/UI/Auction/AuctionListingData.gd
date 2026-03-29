extends Resource
class_name AuctionListingData

@export var listing_id: String = ""
@export var title: String = "Auction Listing"
@export_multiline var summary: String = ""
@export var starting_bid: int = 100
@export var min_increment: int = 10
@export var end_timestamp_unix: int = 0
@export var item_uid: String = ""
@export var seller_name: String = "War Table"
@export var seller_id: String = "system"
@export var status: String = "active"
