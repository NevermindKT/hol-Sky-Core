extends Area3D

func body_entered(body: Node3D):
	if body == Car_Movement:
		print("BAM")
