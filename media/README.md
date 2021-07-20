===============================================================================
         Application Templates - README
         Version 1.0, 2021
         Copyright (c) 2021 NetApp, Inc. All rights reserved.
===============================================================================
 
-------------------------------------------------------------------------------
         OVERVIEW
-------------------------------------------------------------------------------
 
Application Templates helps you create ready-to-use, automatically deployed resources structures, with pre-defined company rules / practices and selected services, and enforce them for maximum protection or minimum costs.

Note: Application Templates running in SAAS mode and therefore no installation is required.
 
-------------------------------------------------------------------------------
         MOTIVATION
-------------------------------------------------------------------------------
 
1) A new service that allows creation of templates, that can be later used when creating different resources supplied by Cloud Manager services.
2) The templates, created by a Storage Architect, will maintain a standard and allow knowledge sharing for the entire organization in one place. 
3) The templates are meant to be used by the Storage Administrators, who will use it for resources creation without the need to teach them the "right" configuration.

-------------------------------------------------------------------------------
         PREREQUISITES
-------------------------------------------------------------------------------

1) User should have active connector (Cloud Manager).
2) User should have active working environment (Cloud Volumes ONTAP).
 
-------------------------------------------------------------------------------
         LIMITATIONS
-------------------------------------------------------------------------------

Phase #1: 
1) Application Templates is supported for Cloud Volumes ONTAP only (not supported for OnPrem Cloud Manager).
2) Create volume from existing aggregate is not supported.
3) Create volume in CVO with multiple SVM's is not supported.
4) Application Templates is not supported on GOV Cloud environment.
 
-------------------------------------------------------------------------------
         NOTES
-------------------------------------------------------------------------------
 
Phase #1: 
1) User roles do not take an active part in displaying the different screens (create template/Add volume from template).

-------------------------------------------------------------------------------
         API
-------------------------------------------------------------------------------

# Register action definition:
	POST https://cloudmanager.cloud.netapp.com/application-templates/account/<ACCOUNT_ID>/api/action-definition
	
-------------------------------------------------------------------------------
         SCHEMA SPECIFICATION
-------------------------------------------------------------------------------
 
Note: Schemas are based on JSON schema standard.

# When creating a new action-definition (using POST API), 2 schemas need to be supplied in the request body:
1) "basicSchema" 
2) "viewSchema" 
3) [optional] "applicableTo" - an array of objects that describe the resources that this action can be applied to. 
	Each object has these properties:
	a) "actionDefinitionId" - string that matches the resource's actionDefinition
	b) "rules" - array of objects (can be []), with the following properties:
		i) "path" - dot notation to the relevant property
		ii) "value" - array of allowed values

# The "basicSchema" includes:
1) "definitions". This is an unordered list of all the properties that can have a value. For each property:
	a) "title"
	b) "placeholder" (optional)
	c) "type" - can be string, array, number.
 	d) supported validations: (optional) -
		i) for type "number": "minimum", "maximum"
	e) "default" - default value
	f) "derived"- a value that is derived from a different property (useful for dependencies)
	g) "disabled" - boolean - is this field disabled 
2) "properties" - defines the structure of the resulting object.
	a) If the property was defined in #1, there should be a ref to it.
	b) If the property is an object, it is treated as "sub-schema" - so it should include its own "properties". 
3) "dependencies" (optional)- defines properties that their existence/values depend on other properties values - for the 		current sub-schema.
4) "required" - array of required properties - for the current sub-schema.

Note: #2,3,4 can re-appear in each of the sub-schemas defined in #2.

# The "viewSchema" includes:
1) ""propertiesSections" - array of sections. For each section:
	a) "title"
	b) "description" (optional) - will be shown as tooltip
	c) "properties" - which properties are included in the section - as array
2) "propertiesInfo" - for properties that require UI widget that is not the default. here are the default and the available 	alternatives:
	
	Property type      | Default widget | Alternative widgets | example
	------------------------------------------------------------------
	string             | input[type=text]   | textarea | name
	------------------------------------------------------------------
	number             | input[type=number] |          | size
	------------------------------------------------------------------
	boolean            | checkbox           |          | example
	------------------------------------------------------------------
	enum               | select             | radio    | provider
	------------------------------------------------------------------
	arrays of objects  | Array              |          | tags
	------------------------------------------------------------------
	arrays of strings  | Checkbox array     |          | NFS versions
	------------------------------------------------------------------

-------------------------------------------------------------------------------
         EXAMPLES
-------------------------------------------------------------------------------

basicSchema: {
    "definitions": {
      "name": {
        "title": "Volume Name",
        "placeholder": "Enter Volume name",
        "type": "string",
        "pattern": "^[a-zA-Z][0-9a-zA-Z_]{0,149}$"
      },
      "size": {
        "title": "Volume Size",
        "placeholder": "Enter volume size",
        "type": "number",
        "minimum": 100,
        "maximum": 1000
      },
      "unit": {
        "title": "Size Unit",
        "placeholder": "Select size unit",
        "type": "string",
        "enum": [
          "GB",
          "TB"
        ],
        "enumNames": [
          "GB",
          "TB"
        ]
      },
      "snapshotPolicyName": {
        "title": "Snapshot Policy",
        "placeholder": "Select snapshot policy",
        "type": "string",
        "enum": [
          "default",
          "none"
        ],
        "enumNames": [
          "Default",
          "None"
        ]
      },
      "enableThinProvisioning": {
        "title": "Enable Thin Provisioning",
        "type": "boolean",
        "default": true
      },
      "provider": {
        "title": "Provider",
        "type": "string",
        "enum": [
          "aws",
          "azure",
          "gcp",
          "onprem"
        ],
        "enumNames": [
          "AWS",
          "Azure",
          "GCP",
          "onPrem"
        ]
      },
      "providerVolumeType": {
        "title": "Disk Type",
        "placeholder": "Select disk type",
        "type": "string"
      },
      "capacityTier": {
        "title": "Capacity Tier",
        "type": "string",
        "readOnly": true,
        "disabled": true
      },
      "protocol": {
        "title": "Protocol",
        "type": "string",
        "enum": [
          "nfs",
          "smb"
        ],
        "enumNames": [
          "NFS",
          "SMB"
        ]
      },
      "policyType": {
        "title": "Access Control",
        "placeholder": "Select access control",
        "type": "string",
        "enum": [
          "none",
          "custom"
        ],
        "enumNames": [
          "No access to the volume",
          "Custom export policy"
        ]
      },
      "ips": {
        "title": "Custom Export Policy",
        "type": "array",
        "items": {
          "type": "string",
          "title": "Custom Export Policy"
        }
      },
      "ipsEmpty": {
        "type": "array",
        "minItems": 0,
        "maxItems": 0,
        "items": {
          "type": "string"
        },
        "default": []
      },
      "nfsVersion": {
        "title": "NFS Version",
        "type": "array",
        "items": {
          "type": "string",
          "enum": [
            "nfsv3",
            "nfsv4"
          ],
          "enumNames": [
            "NFSv3",
            "NFSv4"
          ]
        },
        "uniqueItems": true
      },
      "shareName": {
        "title": "Share Name",
        "type": "string"
      },
      "permission": {
        "title": "Permissions",
        "type": "string",
        "enum": [
          "Full Control",
          "Read/Write",
          "Read",
          "No Access"
        ]
      },
      "users": {
        "title": "Users / Groups",
        "type": "array",
        "items": {
          "type": "string",
          "title": "Users / Groups"
        }
      },
      "tieringPolicy": {
        "title": "Tiering Policy",
        "placeholder": "Select Tiering policy",
        "type": "string",
        "enum": [
          "none",
          "snapshot_only",
          "auto",
          "all"
        ],
        "enumNames": [
          "None",
          "Snapshot Only",
          "Auto",
          "All"
        ]
      }
    },
    "properties": {
      "name": {
        "$ref": "#/definitions/name"
      },
      "size": {
        "type": "object",
        "properties": {
          "size": {
            "$ref": "#/definitions/size"
          },
          "unit": {
            "$ref": "#/definitions/unit"
          }
        },
        "required": [
          "size",
          "unit"
        ]
      },
      "snapshotPolicyName": {
        "$ref": "#/definitions/snapshotPolicyName"
      },
      "enableThinProvisioning": {
        "$ref": "#/definitions/enableThinProvisioning"
      },
      "provider": {
        "$ref": "#/definitions/provider"
      },
      "protocol": {
        "$ref": "#/definitions/protocol"
      },
      "tieringPolicy": {
        "$ref": "#/definitions/tieringPolicy"
      }
    },
    "dependencies": {
      "provider": {
        "oneOf": [
          {
            "properties": {
              "provider": {
                "enum": [
                  "aws"
                ]
              },
              "providerVolumeType": {
                "$ref": "#/definitions/providerVolumeType",
                "enum": [
                  "gp2",
                  "st1",
                  "sc1",
                  "io1"
                ],
                "enumNames": [
                  "GP2",
                  "ST1",
                  "SC1",
                  "IO1"
                ]
              },
              "capacityTier": {
                "$ref": "#/definitions/capacityTier",
                "default": "S3"
              }
            }
          },
          {
            "properties": {
              "provider": {
                "enum": [
                  "azure"
                ]
              },
              "providerVolumeType": {
                "$ref": "#/definitions/providerVolumeType",
                "enum": [
                  "Premium_LRS",
                  "StandardSSD_LRS",
                  "Standard_LRS"
                ],
                "enumNames": [
                  "Premium SSD",
                  "Standard SSD",
                  "Standard HDD"
                ]
              },
              "capacityTier": {
                "$ref": "#/definitions/capacityTier",
                "default": "Blob"
              }
            }
          },
          {
            "properties": {
              "provider": {
                "enum": [
                  "gcp"
                ]
              },
              "providerVolumeType": {
                "$ref": "#/definitions/providerVolumeType",
                "enum": [
                  "pd-ssd",
                  "pd-standard"
                ],
                "enumNames": [
                  "SSD",
                  "Standard"
                ]
              },
              "capacityTier": {
                "$ref": "#/definitions/capacityTier",
                "default": "cloudStorage"
              }
            }
          }
        ]
      },
      "protocol": {
        "oneOf": [
          {
            "properties": {
              "protocol": {
                "enum": [
                  "nfs"
                ]
              },
              "exportPolicyInfo": {
                "type": "object",
                "properties": {
                  "policyType": {
                    "$ref": "#/definitions/policyType"
                  }
                },
                "dependencies": {
                  "policyType": {
                    "oneOf": [
                      {
                        "properties": {
                          "policyType": {
                            "enum": [
                              "custom"
                            ]
                          },
                          "ips": {
                            "$ref": "#/definitions/ips"
                          },
                          "nfsVersion": {
                            "$ref": "#/definitions/nfsVersion"
                          }
                        },
                        "required": [
                          "ips",
                          "nfsVersion"
                        ]
                      },
                      {
                        "properties": {
                          "policyType": {
                            "enum": [
                              "none"
                            ]
                          },
                          "ips": {
                            "$ref": "#/definitions/ipsEmpty"
                          }
                        }
                      }
                    ]
                  }
                },
                "required": [
                  "policyType"
                ]
              }
            }
          },
          {
            "properties": {
              "protocol": {
                "enum": [
                  "smb"
                ]
              },
              "shareInfo": {
                "type": "object",
                "properties": {
                  "shareName": {
                    "$ref": "#/definitions/shareName"
                  },
                  "accessControl": {
                    "type": "object",
                    "properties": {
                      "permission": {
                        "$ref": "#/definitions/permission"
                      },
                      "users": {
                        "$ref": "#/definitions/users"
                      }
                    },
                    "required": [
                      "permission",
                      "users"
                    ]
                  }
                },
                "required": [
                  "shareName"
                ]
              }
            }
          }
        ]
      }
    },
    "required": [
      "name",
      "size",
      "unit",
      "snapshotPolicyName",
      "enableThinProvisioning",
      "protocol"
    ]
  }

viewSchema: {
    "propertiesSections": [
      {
        "title": "Details & Protection",
        "description": "Volume Details and snapshot policy",
        "properties": [
          "name",
          "size",
          "snapshotPolicyName"
        ]
      },
      {
        "title": "Usage Profile",
        "description": "Usage Profile",
        "properties": [
          "enableThinProvisioning"
        ]
      },
      {
        "title": "Disk Type",
        "description": "Disk Type",
        "properties": [
          "provider"
        ]
      },
      {
        "title": "Protocol",
        "description": "Protocol",
        "properties": [
          "protocol"
        ]
      },
      {
        "title": "Tiering Policy",
        "properties": [
          "tieringPolicy"
        ]
      }
    ],
    "propertiesInfo": {
      "protocol": {
        "ui:widget": "radio"
      }
    }
  }