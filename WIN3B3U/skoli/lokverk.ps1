Rename-NetAdapter -Name "Ethernet 2" -NewName "LAN"
New-NetIPAddress -InterfaceAlias LAN -IPAddress 10.10.1.1 -PrefixLength 22 
Set-DnsClientServerAddress -InterfaceAlias LAN -ServerAddresses 10.10.1.1

Install-WindowsFeature -Name DHCP -IncludeManagementTools
Add-DhcpServerv4Scope -Name TskoliScope -StartRange 10.10.1.3 -EndRange 10.10.3.254 -SubnetMask 255.255.252.0
Set-DhcpServerv4OptionValue -DnsServer 10.10.1.1 -Router 10.10.1.1
Add-DhcpServerInDC -DnsName win3b-05.Taekniskoli.local

Remove-NetIPAddress -IPAddress 10.10.1.2

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