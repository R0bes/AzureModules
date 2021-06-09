
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
        $MAX_TRIES=${var.retries}
        $inc=0
        if ( [System.Convert]::ToBoolean('${var.edge}') ) {
            $edge='--edge-enabled'
        }
        while($inc -lt $MAX_TRIES) {
            $inc = $inc+1
            try {
                $res = az iot hub device-identity $${command} -n '${var.iothub_name}' -d '${var.name} $edge' 2>$1
                if ($res -And !($res -Match "ERROR")) {
                    echo "Success" 
                    break
                }
            }
            catch [Exception]
            {
                echo "An Error occured."
                echo $_.Exception.GetType().FullName, $_.Exception.Message
            } 
        }
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
resource "null_resource" "device" {
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