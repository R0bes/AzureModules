
output "connection_string" {
    value = trimspace(data.local_file.connection_string.content)
    #sensitive = true
}