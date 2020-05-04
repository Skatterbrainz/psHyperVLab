function New-HyperVLabMachines {
	[CmdletBinding()]
	param (
		[parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $VmPath,
		[parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $SwitchName,
		[parameter(Mandatory)][ValidateRange(1,100)][int] $Machines,
		[parameter(Mandatory)][ValidateLength(1,10)][string] $MachinePrefix,
		[parameter(Mandatory)][ValidateRange(1,10)][int] $MachineSuffixLength,
		[parameter()][string] $DiffSource = "",
		[parameter()][string] $ISOPath = "",
		[parameter()][int64] $MaxMemory = 4GB,
		[parameter()][int64] $StartMemory = 1GB,
		[parameter()][int64] $OSDiskSize = 50GB,
		[parameter()][int64] $DataDiskSize1 = 0GB,
		[parameter()][int64] $DataDiskSize2 = 0GB,
		[parameter()][int64] $DataDiskSize3 = 0GB,
		[parameter()][string] $Note = ""
	)
	if ([string]::IsNullOrEmpty($DiffSource) -and [string]::IsNullOrEmpty($ISOPath)) {
		throw "DiffSource and ISOPath cannot both be empty/null"
	}
	for ($id = 1; $id -lt $($Servers+1); $id++) {
		try {
			$vmname = "$($MachinePrefix)$($($id).ToString().PadLeft($MachineSuffixLength,'0'))"
			$vhdpath = "$($vmPath)\$vmname\$($vmname).vhdx"
			if (![string]::IsNullOrEmpty($DiffSource)) {
				Write-Verbose "cloning differencing disk: $($vmname).vhdx"
				New-VHD -Path $vhdpath -ParentPath $DiffSource -Differencing
			}
			else {
				Write-Verbose "creating virtual disk: $($vmname).vhdx"
				New-VHD -Path $vhdpath -SizeBytes $OSDiskSize -Dynamic
			}
			if ($DataDiskSize1 -gt 0) {
				$vhd = "$($vmname)_Disk2.vhdx"
				$vhdpath = "$($vmPath)\$vmname\$vhd"
				Write-Verbose "creating virtual disk: $vhd"
				New-VHD -Path $vhdpath -SizeBytes $DataDiskSize1 -Dynamic
			}
			if ($DataDiskSize2 -gt 0) {
				$vhd = "$($vmname)_Disk3.vhdx"
				$vhdpath = "$($vmPath)\$vmname\$vhd"
				Write-Verbose "creating virtual disk: $vhd"
				New-VHD -Path $vhdpath -SizeBytes $DataDiskSize2 -Dynamic
			}
			if ($DataDiskSize3 -gt 0) {
				$vhd = "$($vmname)_Disk4.vhdx"
				$vhdpath = "$($vmPath)\$vmname\$vhd"
				Write-Verbose "creating virtual disk: $vhd"
				New-VHD -Path $vhdpath -SizeBytes $DataDiskSize3 -Dynamic
			}
			Write-Verbose "creating vm: $vmname"
			$vm = New-VM -Name $vmname -MemoryStartupBytes $StartMemory -NoVHD -SwitchName $SwitchName -Path $vmPath -Version 9.0 -Generation 2
			Write-Verbose "setting vm properties"
			Set-VM -VM $vm -ProcessorCount 2 -DynamicMemory -MemoryMinimumBytes $StartMemory -MemoryMaximumBytes $MaxMemory -Notes $Note | Out-Null
			if (![string]::IsNullOrEmpty($ISOPath)) {
				Write-Verbose "attaching dvd iso: $ISOPath"
				Add-VMDvdDrive -VMName $vmname -Path $ISOPath | Out-Null
			}
			Write-Host "created vm: $vmname"
		}
		catch {
			Write-Error $_.Exception.Message 
		}
	}
}

function Remove-HyperVLabMachines {
	[CmdletBinding()]
	param (
		[parameter(Mandatory)][ValidateLength(1,10)][string] $MachinePrefix,
		[parameter(Mandatory)][ValidateRange(1,100)][int] $Machiness,
		[parameter(Mandatory)][ValidateRange(1,10)][int] $MachineSuffixLength,
		[parameter()][bool] $Cleanup
	)
	for ($id = 1; $id -lt $($Machines+1); $id++) {
		$vmname = "$($MachinePrefix)$($($id).ToString().PadLeft($MachineSuffixLength,'0'))"
		try { 
			Write-Verbose "deleting client: $vmname"
			$vm = Get-VM $vmname -ErrorAction SilentlyContinue
			if ($vm.State -eq 'Running') {
				Write-Verbose "stopping vm: $vmname"
				Stop-VM -VM $vm -TurnOff -Force
			}
			$vm | Remove-VM -Force
			if ($Cleanup -eq $True) {
				Start-Sleep -Seconds 2
				$vpath = "$($vmpath)\$vmname"
				if (Test-Path $vpath) { 
					Write-Verbose "deleting vm folder: $vpath"
					Get-Item -Path $vpath | Remove-Item -Recurse -Force 
				}
			}
			Write-Host "vm destroyed: $vmname"
		}
		catch {
			Write-Error $_.Exception.Message
		}
	}
}
