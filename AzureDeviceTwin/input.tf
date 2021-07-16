

#################
#   Variables   #
#################

variable "name" {
	type = string
	description		= "Name for the device."
}

variable "iothub_name" {
	type = string
	description		= "IoT Hub for the device to live in."
}

variable "edge" {
	type = bool
	default = false
	description		= "Edge Device"
}

variable "retries" {
	type = number
	default = 17
	description		= "Retries on error"
}
