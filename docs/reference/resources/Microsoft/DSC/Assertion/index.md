---
description: Microsoft.DSC/Assertion resource reference documentation
ms.date:     07/24/2026
ms.topic:    reference
title:       Microsoft.DSC/Assertion
---

# Microsoft.DSC/Assertion

## Synopsis

Asserts that a group of nested resource instances are already in the desired state, without
enforcing any changes.

## Metadata

```yaml
Version    : 0.1.0
Kind       : group
Tags       : [Windows, Linux, MacOS]
Author     : Microsoft
```

## Instance definition syntax

```yaml
resources:
  - name: <instance name>
    type: Microsoft.DSC/Assertion
    properties:
      # A configuration document that defines the instances to assert.
      $schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
      resources:
        - name: <nested instance name>
          type: <nested resource type>
          properties:
            # nested resource properties
```

## Description

The `Microsoft.DSC/Assertion` resource is a [group resource][03] that verifies whether a set of
nested resource instances are already in their desired state. Unlike the
[Microsoft.DSC/Group][09] resource, the `Microsoft.DSC/Assertion` resource never enforces state. For
every operation you invoke against it, DSC runs the **Test** operation for each nested instance:

- When every nested instance is in the desired state, the assertion succeeds.
- When any nested instance isn't in the desired state, the assertion fails, DSC reports an
  `Assertion failed` error, and the operation stops.

Because the resource only ever tests, it's useful for guarding a configuration. You can define an
assertion that describes the conditions a system must satisfy, then use the [dependsOn][05] property
to ensure that DSC only processes other resources when the assertion succeeds. For example, you can
assert that a machine runs a specific operating system before DSC configures resources that only
apply to that platform.

The properties of a `Microsoft.DSC/Assertion` instance are a nested configuration document. Define
the instances you want to assert in the [resources](#resources) property, exactly as you would in a
standalone configuration document.

> [!NOTE]
> This resource is installed with DSC itself on any systems.
>
> You can update this resource by updating DSC. When you update DSC, the updated version of this
> resource is automatically available.

### How each operation behaves

The `Microsoft.DSC/Assertion` resource maps every operation onto the **Test** operation for its
nested instances:

- **Get** - Runs **Test** for each nested instance and returns the actual state of the instances.
- **Set** - Runs **Test** for each nested instance. It never invokes **Set** on the nested
  instances, so it never changes system state. The operation fails if any assertion isn't met.
- **Test** - Runs **Test** for each nested instance and returns the test result, including whether
  each instance is in the desired state.

## Capabilities

The resource has the following capabilities:

- `get` - You can use the resource to retrieve the actual state of the nested resource instances.
- `set` - You can use the resource to assert the desired state for the nested resource instances.
  This operation never changes system state.
- `test` - You can use the resource to check whether the nested resource instances are in the
  desired state.

For more information about resource capabilities, see [DSC resource capabilities][01].

## Examples

1. [Assert the state of a machine][07] - Shows how to define a standalone assertion and interpret a
   passing and failing result.
1. [Gate a configuration with an assertion][08] - Shows how to use `dependsOn` so that DSC only
   processes resources when an assertion succeeds.

## Properties

The following list describes the properties for the resource.

- **Required properties:** <a id="required-properties"></a> The following property is always
  required when defining an instance of the resource. An instance that doesn't define this property
  is invalid.

  - [resources](#resources) - The nested resource instances to assert.

### resources

<details><summary>Expand for <code>resources</code> property metadata</summary>

```yaml
Type             : array
ItemsType        : object
IsRequired       : true
IsKey            : false
IsReadOnly       : false
IsWriteOnly      : false
```

</details>

Defines the list of nested resource instances that the assertion tests. Each item in the array is a
resource instance, defined the same way as an instance in the top-level `resources` array of a
[configuration document][04]. DSC runs the **Test** operation for each instance and the assertion
succeeds only when every instance is in the desired state.

Because the properties of a `Microsoft.DSC/Assertion` instance are a configuration document, you can
also define the other configuration document properties, such as `$schema`, `parameters`, and
`variables`, alongside `resources`.

## Exit codes

The resource returns the following exit codes:

- `0` - Success. Every nested instance is in the desired state.
- `1` - Invalid argument.
- `2` - Resource error.
- `3` - JSON serialization error.
- `4` - Invalid input format.
- `5` - Resource instance failed schema validation.
- `6` - Resource operation cancelled.
- `7` - Resource not found.
- `8` - Assertion failed. At least one nested instance isn't in the desired state.

## Instance validating schema

The following snippet contains the JSON Schema that validates an instance of the resource. The
validating schema only includes schema keywords that affect how the instance is validated. All
non validating keywords are omitted.

```json
{
  "type": "object",
  "required": [
    "resources"
  ],
  "properties": {
    "$schema": {
      "type": "string",
      "format": "uri"
    },
    "resources": {
      "type": "array",
      "items": {
        "type": "object"
      }
    }
  }
}
```

## See also

- [Microsoft.DSC/Group resource][09]
- [Microsoft.DSC/Include resource][10]
- [Microsoft/OSInfo resource][11]
- [DSC resource kinds][03]
- [DSC configuration documents][06]

<!-- Link reference definitions -->
[01]: ../../../../../concepts/resources/capabilities.md
[03]: ../../../../../concepts/resources/kinds.md
[04]: ../../../../schemas/config/resource.md
[05]: ../../../../schemas/config/resource.md#dependson
[06]: ../../../../../concepts/configuration-documents/overview.md
[07]: ./examples/assert-the-state-of-a-machine.md
[08]: ./examples/gate-a-configuration-with-an-assertion.md
[09]: ../Group/index.md
[10]: ../Include/index.md
[11]: ../../../Microsoft/OSInfo/index.md
