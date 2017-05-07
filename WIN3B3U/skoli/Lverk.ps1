#------------------------------------------------------------------------------------------
#-- Uppsetning Netkerfis
#------------------------------------------------------------------------------------------

Rename-NetAdapter -Name "Ethernet 2" -NewName "LAN"
New-NetIPAddress -InterfaceAlias LAN -IPAddress 10.10.1.3 -PrefixLength 22 
Set-DnsClientServerAddress -InterfaceAlias LAN -ServerAddresses 127.0.0.1 

Install-WindowsFeature -Name AD-Domain-Services –IncludeManagementTools
Install-ADDSForest –DomainName Taekniskoli.local –InstallDNS -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force)

#------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------
#-- DSC
#------------------------------------------------------------------------------------------

Add-Computer -ComputerName "WIN3B-w81-04" -LocalCredential WIN3B-w81-04\Administrator -DomainName Taekniskoli.local -Credential Taekniskoli.local\Administrator -Restart -Force

$pc = Get-ADComputer -Filter {name -like "Win3b-w81-04"}

Add-WindowsFeature Dsc-Service

Configuration DHCPcheck
{
    param(
        [string[]]$ComputerName='10.10.1.1'
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $ComputerName 
    {
        WindowsFeature DHCP
        {
            Ensure = 'Present'
            Name = 'DHCP'
        }
        Service DHCP
        {
            Name = 'DHCP'
            StartupType = 'Automatic'
            State = 'Running'
        }
    }
}
#------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------
#-- OU - Security groups - Users
#------------------------------------------------------------------------------------------

New-ADOrganizationalUnit -Name "Notendur" -ProtectedFromAccidentalDeletion $false
New-ADGroup -Name "Allir" -Path "ou=Notendur,dc=Taekniskoli,dc=local" -GroupScope Global

$notendur = Import-Csv C:\Users\Administrator\Documents\lokaverk_notendur_u.csv -Delimiter ';'

foreach ($n in $notendur) {

#-- Skólar skilgreindir frá notenda CSV og settir sem efstu OU.

    $skoli = $n.Skóli
    if ((Get-ADOrganizationalUnit -Filter{name -eq $skoli}).name -ne $skoli ) {
        New-ADOrganizationalUnit -Name $skoli -Path "ou=Notendur,dc=Taekniskoli,dc=local" -ProtectedFromAccidentalDeletion $false
        New-ADGroup -Name $skoli -Path "ou=$skoli,ou=Notendur,dc=Taekniskoli,dc=local" -GroupScope Global
        Add-ADGroupMember -Identity "Allir" -Members $skoli
    }


#-- Skóladeildir skilgreindar frá notendum og sett sem OU beint undir skólum
#-- Auka check í IF setningu vegna notenda með tómar deildir sem skilaði villu

    $deild = $n.Deild
    if ($deild -and (Get-ADOrganizationalUnit -SearchBase "ou=$skoli,ou=Notendur,dc=Taekniskoli,dc=local" -Filter {name -like $deild}).Name  -ne $deild) {
        New-ADOrganizationalUnit -Name $deild -Path "OU=$skoli,OU=Notendur,DC=Taekniskoli,DC=local" -ProtectedFromAccidentalDeletion $false
        $ds = ($deild + $skoli)
        $ds
        New-ADGroup -Name $ds -Path "ou=$deild,ou=$skoli,ou=Notendur,dc=Taekniskoli,dc=local" -GroupScope Global
        Add-ADGroupMember -Identity $skoli -Members $ds
    }

#-- Einföld strengjavinnsla til að skipta út íslenskum stöfum

    $nafn = $n.Nafn.ToLower()
    $nafn = $nafn -replace 'á','a' `
                  -replace 'é','e' `
                  -replace 'í','i' `
                  -replace 'ý','y' `
                  -replace 'ú','u' `
                  -replace 'ó','o' `
                  -replace 'ð','d' `
                  -replace 'æ','ae' `
                  -replace 'þ','th'

#-- Athugun á hvort það sé millinafn til að reikna með eða ekki
#-- Substring sækir fyrstu tvo stafi og fyrsta staf í sitthvoru nafni
    $nafnSplit = $nafn.Split(' ')
    if ($nafnSplit.Count -eq 2) {
        $user = $nafnSplit[0].Substring(0,2) + $nafnSplit[1].Substring(0,1)
    }
    elseif ($nafnSplit.Count -eq 3) {
        $user = $nafnSplit[0].Substring(0,2) + $nafnSplit[2].Substring(0,1)
    }

#------------------------------------------------------------------------------------------
#-- Hér er byrjað á því að sækja heildartölu á notendum með sama notendanafn,
#-- ef sú tala er hærri en 0 þá er heildartölunnni bætt við fyrir aftan notendanafnið.
#-- Þetta reyndist vandamál þar sem strax og notendanafn innihélt tölu,
#-- þá hætti teljarinn að telja notendann með og enginn notandi fór hærra en 1.
#-- Eftir margar tilraunir leystum við það með * wildcards og -like.
#----
#-- Þar sem talan í notendanafninu er sú sama og heildartalan þegar notandanum er bætt við,
#-- þá endurnýjast talan þótt notenda sé eytt eða breytt
#------------------------------------------------------------------------------------------

    $ncount = (Get-ADUser -Filter "SamAccountName -like '*$user*'" | measure-object | select-object count).Count
    if ($ncount -gt 0) {
        $user += $ncount
    }

    if ($deild) {
        New-ADUser -Name $n.Nafn -DisplayName $n.Nafn -SamAccountName $user -Department $deild -Path "OU=$deild,OU=$skoli,OU=Notendur,DC=Taekniskoli,DC=local" -AccountPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force) -Enabled $true
    }
    else {
        New-ADUser -Name $n.Nafn -DisplayName $n.Nafn -SamAccountName $user -Path "OU=$skoli,OU=Notendur,DC=Taekniskoli,DC=local" -AccountPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force) -Enabled $true
    }

    Get-ADGroup -Filter {name -like $ds} | Add-ADGroupMember -Members $user
    $user

} #-- End $notendur Foreach

#------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------
#-- Function fyrir GUI til að kalla í
#------------------------------------------------------------------------------------------
function AddUser($nafn, $skoli, $deild) {
    try {
        $nafn = $n.Nafn.ToLower()
        $nafn = $nafn -replace 'á','a' `
                      -replace 'é','e' `
                      -replace 'í','i' `
                      -replace 'ý','y' `
                      -replace 'ú','u' `
                      -replace 'ó','o' `
                      -replace 'ð','d' `
                      -replace 'æ','ae' `
                      -replace 'þ','th'

        $nafnSplit = $nafn.Split(' ')
        if ($nafnSplit.Count -eq 2) {
            $user = $nafnSplit[0].Substring(0,2) + $nafnSplit[1].Substring(0,1)
        }
        elseif ($nafnSplit.Count -eq 3) {
            $user = $nafnSplit[0].Substring(0,2) + $nafnSplit[2].Substring(0,1)
        }
        $ncount = (Get-ADUser -Filter "SamAccountName -like '*$user*'" | measure-object | select-object count).Count
        if ($ncount -gt 0) {
            $user += $ncount
        }

        if ($deild) {
            New-ADUser -Name $n.Nafn -DisplayName $n.Nafn -SamAccountName $user -Department $deild -Path "OU=$deild,OU=$skoli,OU=Notendur,DC=Taekniskoli,DC=local" -AccountPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force) -Enabled $true
        }
        else {
            New-ADUser -Name $n.Nafn -DisplayName $n.Nafn -SamAccountName $user -Path "OU=$skoli,OU=Notendur,DC=Taekniskoli,DC=local" -AccountPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force) -Enabled $true
        }

        Get-ADGroup -Filter {name -like $ds} | Add-ADGroupMember -Members $user
        return $user
    }
    catch {
        return false
    }
}

function DelUser($user) {
    try {
        $dname = Get-ADUser -Filter "SamAccountName -eq '$user'" | Select-Object DistinguishedName
        Remove-ADUser -Identity (Get-ADUser -Filter "SamAccountName -eq '$user'" | Select-Object DistinguishedName).DistinguishedName
        return true
    }
    catch {
        return false
    }
}

#------------------------------------------------------------------------------------------
