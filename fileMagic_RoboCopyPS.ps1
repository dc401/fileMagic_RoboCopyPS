<#
Quick and dirty:
Utilize file magic to copy files rather than by extension recursively
Preserve NTFS timestamps
Follow the prompts closely.

Requirements:
PowerShell v3+ or later
File.exe and its dependencies including Magic DB
Access from the command prompt or pre-mapped shares for remote needs


dchow[AT]xtecsystems.com
2015-Jan-19
www.xtecsystems.com


#>


#version check
If ($PSVersionTable.PSVersion.Major -ge 3)
{

    If (( Test-Path .\file.exe -IsValid) -and (Test-Path .\magic -IsValid))
    {
        Write-Host "fileMagic_RoboCopyPS v1.0"
        $srcPath = Read-Host "Please enter your SOURCE path. Ex: c:\*.* or \\foo\bar\*.*"
        Write-Host "You entered:" $srcPath -ForegroundColor Green -BackgroundColor Black "to copy"
        $dstPath = Read-Host "Please enter your DESTINATION path. Ex: c:\dest or \\foo\dest"
        Write-Host "You entered:" $dstPath -ForegroundColor Green -BackgroundColor Black "to write to"
        $extName = Read-Host "Enter a string MAGIC description you want to search for. e.g. PDF if you expect 'PDF Document'"
        Write-Host "You entered:" $extName -ForegroundColor Green -BackgroundColor Black to "search headers for"

        Try
        {
            #Scan file magic against directory
            .\file.exe -F "," -m .\magic -p $srcPath | Out-File -Append tmpFileMagic.csv

            #Grab the dump file and import into as CSV with header into memory optimized
            Import-Csv -header "FilePath","FileType","Version" tmpFileMagic.csv `
            | ForEach-Object $_ `
                {
                    #Allow users to specify the type of file they want
                    If ( $_.Filetype -like "*$extName*")
                    {
                        Tee-Object -InputObject $_.FilePath -Append tmpFilteredFiles.txt
                    }
                }

        }
        Catch
        {
            Write-Host "An error condition has occured. Please check your inputs." -foregroundcolor red -backgroundcolor yellow
            echo $_.Exception | Format-List -Force
        }


        Try
        {
            #Import list of filtered files by file magic type and begin robocopy to destination
            ForEach ($x in (Get-Content tmpFilteredFiles.txt))
                {

                    #Robocopy adds trailing slashes and doesn't take direct file names
                    $resultsBasePath = Split-Path -Path $x
                    $fileNamePath = $x | Split-Path -Leaf

                    #keep MAC times attributes and copy to destination
                    robocopy.exe $resultsBasePath $dstPath $fileNamePath '/COPY:DAT'

                }

        }
    
        Catch
        {
            Write-Host "An error condition has occured. Please check your inputs." -foregroundcolor red -backgroundcolor yellow
            echo $_.Exception | Format-List -Force
        }

        Try
        {
            <#
            Hash the files copied to the target folder Hashing files the files against source remotely takes a while.
            User needs to x-compare the hashes to the source, which on windows, may change due to AV scans.
            #>
            Get-FileHash -Algorithm MD5 -Path $dstPath\*.* | Format-Table -Wrap | Out-File -FilePath $dstPath\discovered_files_md5.txt
            Write-Host "Log of hashes written to: discovered_files_md5.txt under $dstPath"

        }
    
        Catch
        {
            Write-Host "An error condition has occured. Please check your inputs." -foregroundcolor red -backgroundcolor yellow
            echo $_.Exception | Format-List -Force
        }

    }


#clean up temp files
Rename-Item tmpFilteredFiles.txt -Force
Remove-Item tmpFileMagic.csv -Force

Else
    {
    Write-Host "You need PS version 3 or higher." -foregroundcolor red -backgroundcolor yellow
    Write-Host "Download WMF v5 here: https://www.microsoft.com/en-us/download/details.aspx?id=50395 "
    Write-Host "OR"
    Write-Host "You are missing file magic and or magic db"
    Write-Host "File Magic Gnuwin32: binary + dependencies: http://gnuwin32.sourceforge.net/packages/file.htm"
    Write-Host "Exiting..."
    exit
    }
}