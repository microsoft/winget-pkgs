# Troubleshooting Errors
Many of the issues can be caught before submitting your PR, if you follow these steps:
1) Validate the manifest file by running ```winget validate <manifest>```
2) Run the installer with the manifest on your local machine.  This will verify the Sha256 HASH.  ```winget install --manifest <manifest>``` or ```winget install -m <manifest>```

Once those steps pass, here are some troubleshooting tips:

## Manifest-Validation-Error 
Manifest validation errors indicate that there is a problem with the manifest file.  Many of the issues can be caught before submitting your PR, if you validated the manifest file before submission:  ```winget validate <manifest>```

For documentation on the manifest specification, please see the [manifest schema](/doc/manifest/schema)

Here are some common mistakes not discovered by the winget validater.
1) Make sure the publisher folder and application name folder match the Id.  

```id: <publisher>.<name>```  

```folder path: publisher\name```

2) Check for typos in the version.  The file name of the manifest must match the ```Version``` in the manifest  

```Version: 123.456```  

```filename: 123.456.yaml```


## Binary-Validation-Error
Binary validation errors indicate that the installer failed static analysis.  

Here are some common causes for the Binary-Validation-Error label:
1) The Sha256 HASH in the manifest does not match the HASH of the installer. Run ```winget hash <installer>``` to generate the hash.
2) The URL is not valid. Make sure the URL to the installer is publicly available and valid.
3) The installer has been identified as malware.  If the installer is detected as malware, you can submit the installer to the defender team for [analysis](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-antivirus/antivirus-false-positives-negatives#submit-a-file-to-microsoft-for-analysis) as a potential false positive.

## SmartScreen-Validation-Error
SmartScreen validation errors indicate that the URL you provided has a bad reputation.

## Internal-Error
Internal-Errors indicate there was an error hit by the service.  Microsoft will investigate these and pursue a fix.  For a list of known issues, see our repo [issues](https://github.com/microsoft/winget-pkgs/issues)



