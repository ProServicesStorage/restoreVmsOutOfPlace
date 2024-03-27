# restoreVmsOutOfPlace
Restore VMWare VM's in bulk out-of-place using the Commvault REST API

- Prefix added to restored VM is DRTest_ but can be changed. See `$prefix` variable
- Change the `$cs` and `$hypervisor` variables to match your environment
- If using domain credentials then use format `user@domain.example`
- Create folder `C:\cvscripts` and run script from this folder
