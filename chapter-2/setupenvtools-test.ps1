# Set PowerShell Execution Policy
Set-ExecutionPolicy Unrestricted -Force

# Install Chocolatey with optimized settings
$env:chocolateyVersion = '1.4.0'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Create folder structure for pentest tools (do this first to avoid parallel creation issues)
$folders = @(
    "$env:SystemDrive\PentestTools",
    "$env:SystemDrive\PentestTools\Azure",
    "$env:SystemDrive\PentestTools\Azure\Attack",
    "$env:SystemDrive\PentestTools\Azure\Attack\BloodHound",
    "$env:SystemDrive\PentestTools\Azure\Attack\StormSpotter",
    "$env:SystemDrive\PentestTools\Azure\Assessment",
    "$env:SystemDrive\PentestTools\Azure\VulnerableEnv"
)
foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

# Add the pentest tools folder to the Windows Defender exclusion list
Add-MpPreference -ExclusionPath "$env:SystemDrive\PentestTools"

# Update $env:Path
$env:Path += ";$env:SystemDrive\PentestTools\Azure\Attack;$env:SystemDrive\PentestTools\Azure\Assessment;$env:SystemDrive\PentestTools\Azure\VulnerableEnv"
[System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)

# Disable IE First Run (Needed by some tools) - do this early to avoid waiting later
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" -Name "Main" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "RunOnceComplete" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "RunOnceHasShown" -Value 1 -Type DWord -Force

# Disable IE Enhanced Security Configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0

# Batch Install CLI tools - split into smaller, more targeted jobs for faster completion
Start-Job -Name "CoreTools" -ScriptBlock {
    choco install googlechrome azure-cli jq -y --limit-output --no-progress --ignore-checksums
}

Start-Job -Name "DevTools" -ScriptBlock {
    choco install nodejs.install go rust -y --limit-output --no-progress
}

Start-Job -Name "InfraTools" -ScriptBlock {
    choco install terraform pulumi docker-desktop -y --limit-output --no-progress
}

Start-Job -Name "SecurityTools" -ScriptBlock {
    choco install nmap -y --limit-output --no-progress
}

Start-Job -Name "PythonSetup" -ScriptBlock {
    choco install python -y --limit-output --no-progress
}

# Split PowerShell modules installation into smaller batches
Start-Job -Name "PSModules1" -ScriptBlock {
    Install-Module -Name Az -Force -AllowClobber -SkipPublisherCheck
}

Start-Job -Name "PSModules2" -ScriptBlock {
    Install-Module -Name AzureAD -Force -AllowClobber -SkipPublisherCheck
    Install-Module -Name AzureADPreview -Force -AllowClobber -SkipPublisherCheck
}

Start-Job -Name "PSModules3" -ScriptBlock {
    Install-Module -Name Microsoft.Graph -Force -AllowClobber -SkipPublisherCheck
    Install-Module -Name AADInternals -Force -SkipPublisherCheck
    Install-Module -Name MSOnline -Force -AllowClobber -SkipPublisherCheck
}

# Split Git Clones into multiple smaller jobs for better parallelization
Start-Job -Name "GitClones1" -ScriptBlock {
    # Essential attack tools
    git clone --depth 1 https://github.com/Azure/Stormspotter.git "$env:SystemDrive\PentestTools\Azure\Attack\StormSpotter"
    git clone --depth 1 https://github.com/NetSPI/MicroBurst.git "$env:SystemDrive\PentestTools\Azure\Attack\MicroBurst"
    git clone --depth 1 https://github.com/hausec/PowerZure.git "$env:SystemDrive\PentestTools\Azure\Attack\PowerZure"
    git clone --depth 1 https://github.com/azurekid/blackcat.git "$env:SystemDrive\PentestTools\Azure\Attack\BlackCat"
}

Start-Job -Name "GitClones2" -ScriptBlock {
    # Additional attack tools
    git clone --depth 1 https://github.com/BloodHoundAD/BARK "$env:SystemDrive\PentestTools\Azure\Attack\BARK"
    git clone --depth 1 https://github.com/BishopFox/cloudfox.git "$env:SystemDrive\PentestTools\Azure\Attack\cloudfox"
    git clone --depth 1 https://github.com/cyberark/SkyArk "$env:SystemDrive\PentestTools\Azure\Attack\SkyArk"
    git clone --depth 1 https://github.com/dafthack/MSOLSpray "$env:SystemDrive\PentestTools\Azure\Attack\MSOLSpray"
}

Start-Job -Name "GitClones3" -ScriptBlock {
    # Assessment tools
    git clone -b SASTokenVer --depth 1 https://github.com/jsa2/AADAppAudit "$env:SystemDrive\PentestTools\Azure\Assessment\AADAppAudit"
    git clone --depth 1 https://github.com/csandker/Azure-AccessPermissions.git "$env:SystemDrive\PentestTools\Azure\Assessment\Azure-AccessPermissions"
    git clone --depth 1 https://github.com/nccgroup/ScoutSuite "$env:SystemDrive\PentestTools\Azure\Assessment\ScoutSuite"
}

Start-Job -Name "GitClones4" -ScriptBlock {
    # Vulnerable environments
    git clone --depth 1 https://github.com/mvelazc0/BadZure "$env:SystemDrive\PentestTools\Azure\VulnerableEnv\BadZure"
    git clone --depth 1 https://github.com/ine-labs/AzureGoat "$env:SystemDrive\PentestTools\Azure\VulnerableEnv\AzureGoat"
}

Start-Job -Name "GitClones5" -ScriptBlock {
    # More vulnerable environments
    git clone --depth 1 https://github.com/XMCyber/XMGoat "$env:SystemDrive\PentestTools\Azure\VulnerableEnv\XMGoat"
    git clone --depth 1 https://github.com/mandiant/Azure_Workshop "$env:SystemDrive\PentestTools\Azure\VulnerableEnv\Mandiant-Azure-Workshop"
    git clone --depth 1 https://github.com/Azure/CONVEX "$env:SystemDrive\PentestTools\Azure\VulnerableEnv\Convex"
}

# Download tools in parallel
Start-Job -Name "DownloadTools" -ScriptBlock {
    # Create download folder if it doesn't exist
    if (-not (Test-Path "$env:SystemDrive\Downloads")) {
        New-Item -ItemType Directory -Path "$env:SystemDrive\Downloads" -Force | Out-Null
    }

    # Download all tools in parallel
    $downloads = @(
        @{
            Uri = "https://github.com/BloodHoundAD/AzureHound/releases/download/v2.0.4/azurehound-windows-amd64.zip"
            OutFile = "$env:SystemDrive\Downloads\AzureHound.zip"
            Destination = "$env:SystemDrive\PentestTools\Azure\Attack\AzureHound"
        },
        @{
            Uri = "https://github.com/cisagov/ScubaGear/releases/download/0.3.0/ScubaGear-0.3.0.zip"
            OutFile = "$env:SystemDrive\Downloads\ScubaGear.zip"
            Destination = "$env:SystemDrive\PentestTools\Azure\Assessment"
        },
        @{
            Uri = "https://github.com/ermetic-research/cnappgoat/releases/download/v0.1.0-beta/cnappgoat_0.1.0-beta_Windows-64bit.zip"
            OutFile = "$env:SystemDrive\Downloads\CNAPPGoat.zip"
            Destination = "$env:SystemDrive\PentestTools\Azure\VulnerableEnv\CNAPPGoat"
        }
    )

    # Start downloading in parallel
    $jobs = @()
    foreach ($download in $downloads) {
        $jobs += Start-Job -ScriptBlock {
            param($Uri, $OutFile)
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
        } -ArgumentList $download.Uri, $download.OutFile
    }

    # Wait for all downloads to complete
    $jobs | Wait-Job | Out-Null

    # Extract all downloaded files
    foreach ($download in $downloads) {
        if (Test-Path $download.OutFile) {
            # Create destination directory if it doesn't exist
            if (-not (Test-Path $download.Destination)) {
                New-Item -ItemType Directory -Path $download.Destination -Force | Out-Null
            }
            
            # Extract the archive
            Expand-Archive -Path $download.OutFile -DestinationPath $download.Destination -Force
            
            # Special handling for ScubaGear (unblock files)
            if ($download.OutFile -like "*ScubaGear*") {
                Get-ChildItem -Recurse "$env:SystemDrive\PentestTools\Azure\Assessment\ScubaGear-0.3.0" | Unblock-File
            }
            
            # Remove the downloaded zip file
            Remove-Item -Path $download.OutFile -Force
        }
    }
}

# Install Python Libraries - use direct path to pip and optimize
Start-Job -Name "PythonLibraries" -ScriptBlock {
    $piplocation = "$env:SystemDrive\Python37\Scripts"
    # Install all libraries at once to reduce overhead
    . $piplocation\pip.exe install -q --no-cache-dir flask requests python-dotenv pylint matplotlib pillow requests-futures ordereddict pipenv dnspython astroid autopep8 azure-core azure-identity azure-mgmt-compute azure-mgmt-core azure-mgmt-storage PyInputPlus azure-mgmt-network azure-mgmt-resource azure-common numpy urllib3==1.26 roadrecon
}

# Import BlackCat module at the end when installation is complete
Start-Job -Name "ImportModules" -ScriptBlock {
    # Script will run after all modules are installed
    Write-Output "Waiting for modules to be installed..."
    Start-Sleep -Seconds 10
    Import-Module "$env:SystemDrive\PentestTools\Azure\Attack\BlackCat\blackcat.psd1" -Force
} -Trigger (Get-Job -Name "GitClones1" | Wait-Job)

# Add Script to deploy BloodHound
$filePath = "$env:SystemDrive\PentestTools\Azure\Attack\BloodHound\install-bloodhound.ps1"
$scriptContent = @'
function Ensure-DockerRunning {
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue

    if (-not $dockerProcess) {
        Write-Output "Docker process is not running. Starting Docker..."
        $dockerPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        Start-Process -Wait -FilePath $dockerPath -ArgumentList "-AcceptLicense"
        Write-Output "Docker has been started successfully."
    } else {
        Write-Output "Docker process is already running."
    }
}

Ensure-DockerRunning

# Download and run BloodHound using Docker Compose
Write-Output "Downloading BloodHound docker-compose.yml file..."
$dockerComposeYml = Invoke-WebRequest -Uri "https://github.com/SpecterOps/BloodHound/raw/main/examples/docker-compose/docker-compose.yml" -UseBasicParsing

Write-Output "Starting BloodHound using Docker Compose..."
$dockerComposeYml.Content | docker compose -f - up | Out-File -FilePath "$env:SystemDrive\bloodhound-output.log"

Write-Output "BloodHound has been started and logs are saved to $env:SystemDrive\bloodhound-output.log"
'@
$scriptContent | Out-File $filePath
Write-Output "Script has been saved to $filePath"

# Add Script to deploy Stormspotter
$filePath = "$env:SystemDrive\PentestTools\Azure\Attack\StormSpotter\install-stormspotter.ps1"
$scriptContent = @'
function Ensure-DockerRunning {
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue

    if (-not $dockerProcess) {
        Write-Output "Docker process is not running. Starting Docker..."
        $dockerPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        Start-Process -Wait -FilePath $dockerPath -ArgumentList "-AcceptLicense"
        Write-Output "Docker has been started successfully."
    } else {
        Write-Output "Docker process is already running."
    }
}

Ensure-DockerRunning

# Download and run StormSpotter using Docker Compose
Write-Output "Downloading StormSpotter docker-compose.yml file..."
$dockerComposeYml = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/Stormspotter/main/docker-compose.yaml" -UseBasicParsing

Write-Output "Starting StormSpotter using Docker Compose..."
$dockerComposeYml.Content | docker compose -f - up | Out-File -FilePath "$env:SystemDrive\StormSpotter-output.log"

Write-Output "StormSpotter has been started and logs are saved to $env:SystemDrive\StormSpotter-output.log"
'@
$scriptContent | Out-File $filePath
Write-Output "Script has been saved to $filePath"

# Add a status checker job that will show progress
Start-Job -Name "StatusChecker" -ScriptBlock {
    $totalJobs = (Get-Job).Count - 1  # Excluding self
    $startTime = Get-Date
    
    while ($true) {
        $completedJobs = (Get-Job | Where-Object { $_.Name -ne "StatusChecker" -and $_.State -in @("Completed", "Failed") }).Count
        $elapsedTime = (Get-Date) - $startTime
        
        $percentComplete = [math]::Round(($completedJobs / $totalJobs) * 100)
        
        Write-Output "Progress: $percentComplete% complete ($completedJobs/$totalJobs jobs). Time elapsed: $($elapsedTime.ToString('hh\:mm\:ss'))"
        
        if ($completedJobs -eq $totalJobs) {
            Write-Output "All jobs completed in $($elapsedTime.ToString('hh\:mm\:ss'))"
            break
        }
        
        Start-Sleep -Seconds 10
    }
}

# Wait for all jobs to complete with timeout mechanism
$timeout = 1800  # 30 minutes timeout
$sw = [System.Diagnostics.Stopwatch]::StartNew()

while ((Get-Job | Where-Object { $_.State -eq 'Running' -and $_.Name -ne "StatusChecker" }) -and $sw.Elapsed.TotalSeconds -lt $timeout) {
    Start-Sleep -Seconds 5
}

# Force completion if timeout is reached
if ($sw.Elapsed.TotalSeconds -ge $timeout) {
    Get-Job | Where-Object { $_.State -eq 'Running' -and $_.Name -ne "StatusChecker" } | Stop-Job -Force
    Write-Warning "Some jobs were terminated due to timeout. The setup might be incomplete."
}

# Check for failed jobs
$failedJobs = Get-Job | Where-Object { $_.State -eq 'Failed' -and $_.Name -ne "StatusChecker" }

if ($failedJobs.Count -gt 0) {
    # Output the errors for logging purposes
    $failedJobs | ForEach-Object {
        Write-Error "Job $($_.Name) ($($_.Id)) failed with reason: $($_.ChildJobs[0].JobStateInfo.Reason.Message)"
    }
    Write-Warning "Some jobs failed. The setup might be incomplete."
}

Write-Output "Setup completed in $($sw.Elapsed.ToString('hh\:mm\:ss'))."

# Clean up completed jobs
Get-Job | Remove-Job -Force
