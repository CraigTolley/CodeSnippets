// This is a custom module for obtaining information about a subnet.
// When this module is used and supplied with a subnet to look up, it will return information about the subnet, including the base address, prefix length, gateway, DNS servers, etc
// Optionally, you can provide a 'nthIp' value, and when that is requersted the nth usuable IP in the subnet will be returned.
// This does not guarantee that the IP address is actually available though.

@description('Name of the resource group containing the virtual network')
param rgName string

@description('Name of the virtual network containing the required subnet')
param vNetName string

@description('Name of the subnet to get details of')
param sNetName string

@description('''
Optional.
When specified, the full IP address of the nth useable IP address in the subnet will be returned.
If the returned value is empty, then the requested IP address is out of range of the subnet
''')
param nthIp int = 0

resource virtualNetworkObj 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: vNetName
  scope: resourceGroup(rgName)
}

resource subnetObj 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' existing = {
  name: sNetName
  parent: virtualNetworkObj
}

// Basic subnet details
var subnetParts = split(split(subnetObj.properties.addressPrefix, '/')[0], '.')
var subnetMask = int(split(subnetObj.properties.addressPrefix, '/')[1])
output subnetPrefix string = subnetObj.properties.addressPrefix
output subnetBaseAddress string = split(subnetObj.properties.addressPrefix, '/')[0]
output subnetPrefixLength int = subnetMask

// Gateway and DNS Server addresses
var subnetFirst3Octets = '${subnetParts[0]}.${subnetParts[1]}.${subnetParts[2]}'
output gateway string = '${subnetFirst3Octets}.${string((int(subnetParts[3]) + 1))}'
output dns1 string = '${subnetFirst3Octets}.${string((int(subnetParts[3]) + 2))}'
output dns2 string = '${subnetFirst3Octets}.${string((int(subnetParts[3]) + 3))}'
output firstUseableIp string = '${subnetFirst3Octets}.${string((int(subnetParts[3]) + 4))}'

// Calculate the number of IPs. No exponential function in Bicep at this time, nor the ability to loop and update a variable, so resort to a static list
// /29 is the smallest subnet and the largest is /2 in Azure
var sNetSizes = {
  S29: 8
  S28: 16
  S27: 32
  S26: 64
  S25: 128
  S24: 256
  S23: 512
  S22: 1024
  S21: 2048
  S20: 4096
  S19: 8192
  S18: 16384
  S17: 32768
  S16: 65536
  S15: 131072
  S14: 262144
  S13: 524288
  S12: 1048576
  S11: 2097152
  S10: 4194304
  S9: 8388608
  S8: 16777216
  S7: 33554432
  S6: 67108864
  S5: 134217728
  S4: 268435456
  S3: 536870912
  S2: 1073741824
}
var numIps = sNetSizes['S${subnetMask}']

// Calculate last useable IP and the broadcast address
var ipsToAdd = numIps - 1 // Exclude base address
var endIpOctet1 = string(int(subnetParts[0]) + (ipsToAdd / 16777216))
var ipsToAddOctet2 = ipsToAdd - ((ipsToAdd / 16777216) * 16777216)
var endIpOctet2 = string(int(subnetParts[1]) + (ipsToAddOctet2 / 65536))
var ipsToAddOctet3 = ipsToAddOctet2 - ((ipsToAddOctet2 / 65536) * 65536)
var endIpOctet3 = string(int(subnetParts[2]) + (ipsToAddOctet3 / 256))
var ipsToAddOctet4 = ipsToAddOctet3 - ((ipsToAddOctet3 / 256) * 256)
var endIpOctet4 = string(int(subnetParts[3]) + (ipsToAddOctet4 - 1))
var broadcastAddress = string(int(subnetParts[3]) + (ipsToAddOctet4))
output lastUseableIp string = '${endIpOctet1}.${endIpOctet2}.${endIpOctet3}.${endIpOctet4}'
output broadcastAddress string = '${endIpOctet1}.${endIpOctet2}.${endIpOctet3}.${broadcastAddress}'

// Output the total number of IP addresses and useable IP addressess
output numAddressesTotal int = numIps
output numAddressesUseable int = numIps - 5 // Subtract 5 for Gateway, Broadcast, DNS1, DNS2, Network Address

// Calculate what the nth IP address is in the range
var nthipsToAdd = nthIp + 3 // Exclude gateway, dns1 and dns2
var nthendIpOctet1 = string(int(subnetParts[0]) + (nthipsToAdd / 16777216))
var nthipsToAddOctet2 = nthipsToAdd - ((ipsToAdd / 16777216) * 16777216)
var nthendIpOctet2 = string(int(subnetParts[1]) + (nthipsToAddOctet2 / 65536))
var nthipsToAddOctet3 = nthipsToAddOctet2 - ((nthipsToAddOctet2 / 65536) * 65536)
var nthendIpOctet3 = string(int(subnetParts[2]) + (nthipsToAddOctet3 / 256))
var nthipsToAddOctet4 = nthipsToAddOctet3 - ((nthipsToAddOctet3 / 256) * 256)
var nthendIpOctet4 = string(int(subnetParts[3]) + (nthipsToAddOctet4))
var nthendIp = '${nthendIpOctet1}.${nthendIpOctet2}.${nthendIpOctet3}.${nthendIpOctet4}'

// Only return a value if we are asked for an nthIp, and if the nth IP is actually in the subnet
output nthIpAddress string = nthIp != 0 && nthipsToAdd < (numIps - 5) ? nthendIp : ''
