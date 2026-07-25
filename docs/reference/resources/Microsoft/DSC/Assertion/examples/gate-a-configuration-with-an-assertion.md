---
description: >-
  Demonstrates how to use the Microsoft.DSC/Assertion resource with dependsOn to gate a
  configuration so that resources only run when an assertion succeeds.
ms.date:     07/24/2026
ms.topic:    reference
title:       Gate a configuration with an assertion
---

This example demonstrates how to use the `Microsoft.DSC/Assertion` resource as a guard for a
configuration. By combining the assertion with the [dependsOn][01] property, you ensure that DSC only
processes other resources when the machine already satisfies the asserted conditions.

## Define the gated configuration

Author a configuration document with two resource instances:

- A `Microsoft.DSC/Assertion` instance that asserts the machine runs Windows.
- A `Microsoft.Windows/Registry` instance that depends on the assertion.

The registry instance uses the [resourceId()][02] function in its `dependsOn` property to reference
the assertion. DSC processes the assertion first and only continues to the registry instance when the
assertion succeeds.

```yaml
# gated-config.dsc.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: current user registry
    type: Microsoft.Windows/Registry
    properties:
      keyPath: HKCU\example
      _exist: true
    dependsOn:
      - "[resourceId('Microsoft.DSC/Assertion', 'assert windows')]"
  - name: assert windows
    type: Microsoft.DSC/Assertion
    properties:
      $schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
      resources:
        - name: os
          type: Microsoft/OSInfo
          properties:
            family: Windows
```

## Run the configuration

Invoke the [dsc config set][03] command against the document.

```powershell
dsc config set --file ./gated-config.dsc.yaml
```

DSC processes the `assert windows` instance first:

- **When the assertion succeeds** - The machine runs Windows, so DSC continues and enforces the
  desired state for the `current user registry` instance.
- **When the assertion fails** - The machine doesn't run Windows, so DSC reports an
  `Assertion failed` error and doesn't process the dependent registry instance. The command exits
  with a non-zero exit code.

This pattern lets you fail fast when a machine doesn't meet the prerequisites for a configuration,
rather than partially applying it.

> [!NOTE]
> The `Microsoft.DSC/Assertion` resource never changes system state. It only tests the nested
> instances. In this example, the registry instance is the only resource that DSC can change, and
> only when the assertion succeeds.

## See also

- [Microsoft.DSC/Assertion resource](../index.md)
- [Assert the state of a machine](./assert-the-state-of-a-machine.md)
- [Microsoft.Windows/Registry resource][04]

<!-- Link reference definitions -->
[01]: ../../../../../schemas/config/resource.md#dependson
[02]: ../../../../../schemas/config/functions/resourceId.md
[03]: ../../../../../cli/config/set.md
[04]: ../../../../Microsoft/Windows/Registry/index.md
