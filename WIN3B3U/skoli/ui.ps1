#Forrit fyrir mannauðdsdeild

#Hleð inn klösum fyrir GUI, svipað og References í C#
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

#Fall sem sér um að leita að notendum og skilar niðurstöðunni í ListBox-ið

function SkraNotenda {
    $userNafn = $txtNafn.Text
    $userDeild = $lstDeildir.Text
    $nafnToLower = $userNafn.ToLower()
    $charArrayNafn = $nafnToLower.ToCharArray()
    $nafnSplit = $nafnToLower.split(' ')
    foreach($is in $islenskirStafir)
    {
        foreach($c in $charArrayNafn){
           if($is["$c"]) {
                $nafnToLower = $nafnToLower.Replace($c.ToString(), $is["$c"])      
            }
        }
    }
    if (!$userNafn -or !$userDeild)
    {
        Write-Host "Please fill in all textboxes and try again"
    }
    elseif($nafnSplit.Length -lt 2)
    {
        Write-Host "ERROR: Please enter full name of user"
    }
    else{
        if(Get-ADUser -Identity $samaccountname)
        {
            Write-Host "ERROR: User already exists"
        }
        else{
            
            if(($nafnSplit.Length -eq 3) -and $n.Nafn.Length -gt 20)
            {
                $samaccountname = $nafnSplit[0] + "." + $nafnSplit[1] + "." + $nafnSplit[2]
                $samaccountname = $samaccountname.Substring(0,20)
                $givenname = $userNafn.Split(' ')
                $surname = $givenname[2]
                $givenname = $givenname[0] + " " + $givenname[1]
                $samaccountname = $samaccountname.ToLower()
            }
            elseif($nafnSplit.Length -eq 3)
            {
                $samaccountname = $nafnSplit[0] + "." + $nafnSplit[1] + "." + $nafnSplit[2]
                if($samaccountname.Length -gt 20)
                {
                    $samaccountname = $samaccountname.Substring(0,20)
                }
                $givenname = $userNafn.Split(' ')
                $surname = $givenname[2]
                $givenname = $givenname[0] + " " + $givenname[1]
            }
            elseif($nafnSplit.Length -eq 2)
            {
                $samaccountname = $nafnSplit[0] + "." + $nafnSplit[1]
                if($samaccountname.Length -gt 20)
                {
                    $samaccountname = $samaccountname.Substring(0,20)
                }
                $givenname = $userNafn.Split(' ')
                $surname = $givenname[1]
                $givenname = $givenname[0]
            }
            if($chkBox.Checked)
            {
                $websiteName = $samaccountname.replace('.','')
                New-Item $("C:\inetpub\wwwroot\" + $websiteName + ".bbp.is") -ItemType Directory
                New-Item $("C:\inetpub\wwwroot\" + $websiteName + ".bbp.is\index.html") -ItemType File -Value $($websiteName + ".bbp.is")
                New-Website -Name $($websiteName + ".bbp.is") -HostHeader $($websiteName + ".bbp.is") -PhysicalPath $("C:\inetpub\wwwroot\" + $websiteName + ".bbp.is\") -Force
                New-WebBinding -Name $($websiteName + ".bbp.is") -HostHeader "bbp.is"
                Add-DnsServerResourceRecordA -ZoneName "bbp.is" -Name $websiteName -IPv4Address "10.10.0.1"

                Write-Host "Website has been created, Link: http://$websiteName.bbp.is"

                New-Item C:\Deildarmöppur\$userDeild\$userNafn -ItemType Directory 
                $rettindi = Get-Acl -Path C:\Deildarmöppur\$userDeild\$userNafn
                $nyrettindi = New-Object System.Security.AccessControl.FileSystemAccessRule("$samaccountname", "Modify", "Allow") 
                $rettindi.AddAccessRule($nyrettindi) 
                Set-Acl -Path C:\Deildarmöppur\$userDeild\$userNafn $rettindi

                Write-Host "User folder has been created, Path: C:\Deildarmöppur\$userDeild\$userNafn"
            }
        
            New-ADUser -name $userNafn -DisplayName $userNafn -GivenName $givenname -Surname $surname -SamAccountName $samaccountname -UserPrincipalName $($samaccountname + "@ddp-emil.local") -AccountPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force) -Path $("OU=" + $userDeild + ",OU=bbp-Notendur,DC=bbp-emil,DC=local") -Enabled $true
            Add-ADGroupMember -Identity $userDeild -Members $samaccountname
        
            Write-Host "User has been created"
            Write-Host "Name: $userNafn"
            Write-Host "SAMAccountName: $samaccountname"
            Write-Host "Deild: $userDeild"
            
        }    
    }
}


#Aðalglugginn 
#Bý til tilvik af Form úr Windows Forms
$frmCreateUser = New-Object System.Windows.Forms.Form
#Set stærðina á forminu
$frmCreateUser.ClientSize = New-Object System.Drawing.Size(550,400)
#Set titil á formið
$frmCreateUser.Text = "Leita að notendum"

#Leita takkinn
#Bý til tilvik af Button
$btnCreate = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnCreate.Location = New-Object System.Drawing.Point(300,60)
#Set stærðina á takkanum
$btnCreate.Size = New-Object System.Drawing.Size(75,25)
#Set texta á takkann
$btnCreate.Text = "Create user"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnCreate.add_Click({ SkraNotenda })
#Sett takkann á formið
$frmCreateUser.Controls.Add($btnCreate)

#Label Nafn:
#Bý til tilvik af Label
$lblNafn = New-Object System.Windows.Forms.Label
#Set staðsetningu á label-inn
$lblNafn.Location = New-Object System.Drawing.Point(30,30)
#Set stærðina
$lblNafn.Size = New-Object System.Drawing.Size(50,30)
#Set texta á 
$lblNafn.Text = "Fullt Nafn:"
#Set label-inn á formið
$frmCreateUser.Controls.Add($lblNafn)

#Textabox fyrir leitarskilyrðin
#Bý til tilvik af TextBox
$txtNafn = New-Object System.Windows.Forms.TextBox
#Set staðsetninguna
$txtNafn.Location = New-Object System.Drawing.Point(80,30)
#Set stærðina
$txtNafn.Size = New-Object System.Drawing.Size(210,30)
#Set textboxið á formið
$frmCreateUser.Controls.Add($txtNafn)

$lblDeildir = New-Object System.Windows.Forms.Label
$lblDeildir.Location = New-Object System.Drawing.Point(30,66)
$lblDeildir.Size = New-Object System.Drawing.Size(50,30)
$lblDeildir.Text = "Deild:"
$frmCreateUser.Controls.Add($lblDeildir)
#Listbox fyrir leitarniðurstöður
#Bý til tilvik af ListBox
$lstDeildir = New-Object System.Windows.Forms.ComboBox
#Set staðsetningu
$lstDeildir.Location = New-Object System.Drawing.Point(80,60)
#Set stærðina
$lstDeildir.Size = New-Object System.Drawing.Size(210,100)
foreach($a in $allardeildir.Name)
{
    $lstDeildir.Items.Add($a)
}
#Bý til event sem keyrir þegar eitthvað er valið í listboxinu, kalla þá í fallið NotandiValinn
$lstDeildir.add_SelectedIndexChanged( { deildValin } )
#Set listboxið á formið
$frmCreateUser.Controls.Add($lstDeildir)

$chkBox = New-Object System.Windows.Forms.CheckBox
$chkBox.Location = New-Object System.Drawing.Point(300, 25)
$chkBox.Text = "Vefsíða?"
$frmCreateUser.Controls.Add($chkBox)
#Birti formið
$frmCreateUser.ShowDialog()


#fall sem keyrir þegar eitthvað er valið úr listboxinu
function deildValin {
    #TODO hér væri einhver virkni sem keyrði þegar notandi er valinn í listbox-inu
    $Script:userDeild = $lstDeildir.SelectedText
}