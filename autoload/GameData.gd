extends Node

var chart_path: String        # 選択された譜面
var chart_meta: Dictionary    # JSON の先頭メタ部分
var play_stats := {}          # Great/Good/Miss 等

func reset():
	chart_path = ""
	chart_meta = {}
	play_stats = { "score":0, "great":0, "good":0, "miss":0 }
