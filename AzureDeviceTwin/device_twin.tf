
locals {
    # keywords for az cli command
    create = "create"
    destroy = "delete"

    # provide keywords as set
    commands = toset( [ local.create, local.destroy ] ) 
}

# template script to run 'az iot hub device-identity' create or delete command
resource "local_file" "script_template" {
    filename = "device_script.ps1.tmpl"
    content = <<SCRIPT
        $inc=0
        $maxtries='${var.retries}' -as [int]
        $edge=''
        if ( [ System.Convert ]::ToBoolean( '${var.edge}' ) -and ( "$${command}" -eq "create" ) ) {
            $edge='--edge-enabled'
        }
        while( $inc -lt $maxtries ) {
            $inc=$inc+1
            try {
                $res = az iot hub device-identity $${command} -n '${var.iothub_name}' -d '${var.name}' $edge 2>$1
                if ( !( $res -Match "ERROR" ) ) {
                    echo "Success" 
                    exit 0
                }
            }
            catch [ Exception ]
            {
                echo "An Error occured."
                echo $_.Exception.GetType().FullName, $_.Exception.Message
                break
            } 
        }
        exit 1
        SCRIPT
}

# manifest template script in two variants (for each command)
data "template_file" "command_scripts" {
    for_each = local.commands
    template = local_file.script_template.content
    vars = {
        command = each.key
    }
}

# local executor for the two scripts
resource "null_resource" "device_twin" {
    triggers = { 
        create_command =  data.template_file.command_scripts[local.create].rendered 
        destroy_command =  data.template_file.command_scripts[local.destroy].rendered 
    }
    provisioner "local-exec" {
        when = create
        interpreter = ["pwsh" , "-Command"]
        command = self.triggers.create_command
    }
    provisioner "local-exec" {
        when = destroy
        interpreter = ["pwsh" , "-Command"]
        command = self.triggers.destroy_command
    }
}


# connection string
resource "null_resource" "get_connection_string" {
    provisioner "local-exec" {
        interpreter = ["pwsh" , "-Command"]
        command =<<EOT
            $(az iot hub device-identity connection-string show -n '${var.iothub_name}' -d '${var.name}').split('"')[4] | set-content ${var.name}_connection_string.tmp
            EOT
    }
    depends_on = [ null_resource.device_twin ]
}

# connection string file
data "local_file" "connection_string" {
    filename = "./${var.name}_connection_string.tmp"
    depends_on = [ null_resource.get_connection_string ]
}