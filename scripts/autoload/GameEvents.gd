## 全局事件总线 — 解耦跨场景通信
## 所有跨节点事件通过此 Autoload 中转，禁止节点间直接引用
extends Node

signal player_died
signal player_hurt(damage: float)
signal enemy_died(enemy: Node)
signal weapon_changed(weapon_data: Resource)
signal room_cleared
signal room_entered(room_id: String)
signal game_over
signal game_restarted

## 房间事件
signal all_rooms_cleared
signal doors_opened
signal doors_closed

## 计分与道具
signal score_changed(new_score: int)
signal coin_collected(amount: int)
signal item_picked_up(item_data: Resource)
