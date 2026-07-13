---
title: Model generation log
icon: lucide/file-clock
---

# Model generation log

- Baseline commit: `46bed375a21c90d765a5e65010c9f87ae8919b1a`
- Generation-input SHA-256: `eb1cedb83791df5477d3c9f2435fd503bf468b76e0f763ea3ced8c1d4bca1d75`
- Generated at: `2026-07-13T04:25:01+00:00`
- Databricks profile: `bricksgdpr`
- Connection inputs: `DATABRICKS_HOST` and `DATABRICKS_HTTP_PATH` environment variables
- Models generated: `34`
- Artifact workspace: `target/model_generation/` (ignored)

Each command below was executed from the repository root. Specifications are derived from
the checked-in inventory, model SQL, model YAML metadata, and the parsed dbt manifest.
Connection variables were supplied to the harness environment and are intentionally
not expanded in this publication-safe log.

## Artifact and textual-diff summary

| Model | Generator | Kind | Text diff | Generated SQL SHA-256 | Generated YAML SHA-256 |
| --- | --- | --- | ---: | --- | --- |
| `customer_deletion_authorization_history` | `generate_layer1_model` | `CONTROL` | +45/-5 | `1478bc48c9671e3d94d8d7e4082eb5b38212dfae9c535c0d5d084b889fb8d1a6` | `008baaa96af9d6428f6474faf4d14090550352483b75627fed9177bc877228eb` |
| `customer_deletion_authorizations` | `generate_layer1_model` | `CONTROL` | +45/-5 | `9c4f3a92f1fb8390f68add3a0496243d8215eeac79d888f893a9d9ef2863078f` | `ac57feda0615be7ed09838ed638cb96d5c64ec87cb3aeefad2f5d358bb14b3f2` |
| `customer_deletion_requests` | `generate_layer1_model` | `CONTROL` | +28/-6 | `997e1390df3dad281c8d82128666cbb3a643cfe5d702c580cbe47ff1732a2f68` | `caec981d3895b3ba1d1a69ee8453823fda33d11ea7ed9b77f31a141256c2b90e` |
| `quarantine_customer_events` | `generate_layer1_model` | `QUARANTINE` | +45/-5 | `ad1fcc8413378292a74da28e6267a37524cfca5bd8ae640b7c5dd0b5161155dc` | `d3e562560f1dbfd41d0a6c494ada9b06f5461d70ca81b67fd3c1cdfdd20b233c` |
| `quarantine_customer_services` | `generate_layer1_model` | `QUARANTINE` | +55/-5 | `8b1c96d40ea919542b4f225da5dd6ce60b94d9866fa6a1ad0d1dbec65e2ed09b` | `511b13e07dd1d12053dae4282c038841b17ccf9da3fec510d2d0368258d01323` |
| `quarantine_invoices` | `generate_layer1_model` | `QUARANTINE` | +53/-5 | `12a368fda1e51db1334521a98ebd3db29997a71120f0e63a0fade6b7de15df37` | `407e02a306c87bbfb14958fec5bef2135bf16acc20d9ca5027376a285ec2a6f5` |
| `stg_customer` | `generate_layer1_model` | `STAGING` | +54/-0 | `62bd159d32bf7b26ae963874e3c93d9cbea26017b9921905aea66a8a457ae352` | `04e02b0a54a497f32664ed013002a259878dbc8b4c418fd8cf8b27b2e6b52bbf` |
| `stg_customer_deletion_confirmations` | `generate_layer1_model` | `STAGING` | +38/-0 | `f5b646524e313c73b8a86f1aa7f2714a40bf26256ffe4ccf7384a9c5eee5d65b` | `3a5a7e48b624b8529eee1a4be80d63e823b8ce580b714ea98c90c024d9997711` |
| `stg_customer_events` | `generate_layer1_model` | `STAGING` | +32/-0 | `0b0f9a4f3a222e5ecda08e28e5a8e0d7a093fdc2f8eb0b668e7d318721dffa96` | `e92968c70306ea31d40ead059ce14b97fefb745569ab03254b6bf1b628adab0f` |
| `stg_customer_services` | `generate_layer1_model` | `STAGING` | +42/-0 | `3284bfccd43e287378087cbc1637757e4124f17406e2a1935c905b3669c85762` | `e61edcef1f889503ee2ed407b7db61448707c42ead3327392e0fe28359236f62` |
| `stg_invoices` | `generate_layer1_model` | `STAGING` | +40/-0 | `d637dc5e75340b458489e0b60b6c1d335bd7fd408a712f8e2cf1c238fdfd20fd` | `e7b9317fcdfeaca22eb777e77e307801489d7cdb1837555acbdc82688e87b299` |
| `fa_pd_customer` | `generate_priva_map_model` | `MAPPING` | +72/-0 | `3b03d9cd0ee0b6a896239303c82461ca48d34092e91d050697dcf25b5e2a71e0` | `52a442090a1dc9f3cd58621a8df0e694a99ab4bd8af444dece657b53b0211f3b` |
| `fa_pd_service_address` | `generate_priva_map_model` | `MAPPING` | +50/-0 | `617dd7905b4fcb4343c0a373d5e5378de0e195c867bb32ee01cc3f0f3bb69f1e` | `773ca70885dbf26f160e5cf341db51173b1a8d78aef39d24fdb5ad3a317e9e9e` |
| `int_customer_deletion_plan` | `generate_layer2_model` | `CONTROL` | +40/-10 | `4a1708fc343ea38e4f261f6b7e1ca644c4392438891f0b204dae93196e8fbe8f` | `d17c3644ea4cf8150a483e5e501cdd5678bfd16aca1bab6f5d61d766914b7b78` |
| `int_customer_event_resolution` | `generate_layer2_model` | `RESOLUTION` | +45/-1 | `8c0549920b81c71f7314781d56a645fb800ebd692d40221a332ad800e5e22e89` | `05550fb07f57c8fc0eb08586823ae1f4fc4ef286ee7db242226eb00abf31ea38` |
| `int_customer_events_keyed` | `generate_layer2_model` | `KEYED` | +31/-1 | `aa2a2e9ed1c6ef2f3c0483fb0a5d51b9af5bbf290e642df1d1f48c7f1714f940` | `d83eac18aa2b7cff3b2eab96283e91a71c46fd7ade67eee68f8b66e2bd851cbd` |
| `int_customer_events_resolved` | `generate_layer2_model` | `PUBLISHED` | +44/-1 | `ee7d2b02118bc07113726937d1c3f60b629f7121b436d7614749e28f7db870bf` | `b7bbdd0f8c34d5313d8962160d0115cc9805fd82ed8e4a3f1b0716f5d4cfca88` |
| `int_customer_protected` | `generate_layer2_model` | `PUBLISHED` | +51/-1 | `4beba46c7992e2da4ca37515054e7e66b75d928c7cc8dd6a8890ce7784479c1b` | `a5a35a5347955497c95aa9c4f3cbe1f899adb09bebd7122d33d0803d0e8cbdf3` |
| `int_customer_service_resolution` | `generate_layer2_model` | `RESOLUTION` | +46/-1 | `e13359ce7bb71927a9beb68518d0e535dac272c552f3c6c2e2f9876ddd020007` | `70f780f13edba7cbc075e69b8f73e3ad4697b7d2b415e72c898d99037d8b4b2f` |
| `int_customer_services_keyed` | `generate_layer2_model` | `KEYED` | +37/-1 | `27a007954e3c6771d860052398f15963a6fbbc9e9d8f23d053657f01a887e2af` | `30ff70f5b7fce890d47e5b506ad8dac5ea8f75eaeff7d5e8ace084534a33c8bb` |
| `int_customer_services_resolved` | `generate_layer2_model` | `PUBLISHED` | +43/-1 | `1b9705ea1fe7e6360f9e90efeec91e8ffe5e8d5e3f20ac9b6a18028ef2715bda` | `42da553b75a856f48dfdb1a60ff6b68cb9006a9f4015dd3592ddb10eb9874262` |
| `int_invoice_resolution` | `generate_layer2_model` | `RESOLUTION` | +55/-1 | `49f46adb0324b5f83e937e8257bdef48bee726b4390b6621bd3558e47b446f04` | `03bd4194e85d62ecddfdbcdb3755bb2d1606df6a34715c5d82b0d4de9556cdc4` |
| `int_invoices_keyed` | `generate_layer2_model` | `KEYED` | +39/-1 | `f9fd04868f22d73b3884404645e993885aa2517f93bc3f198d948e63bdb02fc8` | `9eca60a75bf4ee79ce6b59a9c37cb6cceca317ade01c1259c6e55966a753b296` |
| `int_invoices_resolved` | `generate_layer2_model` | `PUBLISHED` | +56/-1 | `f21054912ed76078076ac0d46533f7f99f831cbc15c5572428b91185ce65b85a` | `206214a716b9f9a7431d3774f5f676f377fa858cc1c843552d51c84f60326674` |
| `int_terminal_deleted_customer_keys` | `generate_layer2_model` | `CONTROL` | +46/-3 | `df9a544337cab4c9a5789a7690c2d4fb5f69c03eaaa366f36184a0addb982ec5` | `fc335dfe4185c3f9268c15ecdd1e77023bdca6ea8e75e78a03b45211f139eea5` |
| `dim_customer` | `generate_layer3_model` | `DIMENSION` | +51/-1 | `c6363441c42fb336f6e8536880e59d001c1627d32f742771470ac13303000975` | `3e1671fd130816db5aedc23edae19753676cbc398e4a5230e049ac1b228dfbf5` |
| `dim_date` | `generate_layer3_model` | `DATE_DIMENSION` | +4/-1 | `ca3ba565e1aafb92a97f187f85847f06d5579f6e6f0df0fc4567c2a13c16f96b` | `8c96779b69ac0f1b6766b078c693735710eb7f6fdd2eababf725abbf86f87192` |
| `dim_service` | `generate_layer3_model` | `DIMENSION` | +43/-1 | `1e3e2eb3a5e6147ef27e623a75e13c72902e6323b84b83c27a376e20ff31b0e3` | `136134bae8680add820f2cfd42f6db1235d2b66d4900a7874ded62cd25ca6aae` |
| `fct_customer_event` | `generate_layer3_model` | `FACT` | +46/-1 | `ff0158cfbc23049b1eb79407d1991302518a6907c281fcff174469ed06f2a8d2` | `0a13cc68b42413f56a6e8613eb81b7993119c4dd12f0684e1ba51b4ba472f613` |
| `fct_invoice` | `generate_layer3_model` | `FACT` | +56/-1 | `5f565465a1d3401901ed0468cc8443c51f59173e0783c7370924fa1c2cd03605` | `e3c504c0278168e9d535210cd99dd8e819458c6947ef3387de86deb2b021546f` |
| `case_dim_customer` | `generate_layer3_case_model` | `CASE_VIEW` | +49/-1 | `c213716042d255cbd83c4a7f412a9677c7b2197ce2ad38a3415df2ae13945694` | `eabb3e1805fc3818c92f72fa09c6e0fce3b7718b34fe42da5a47a04317539b16` |
| `case_dim_service` | `generate_layer3_case_model` | `CASE_VIEW` | +47/-1 | `e58e675a2af9193ea1207219d2b236622275952dbd000678ac941a59f1ef11dc` | `a451736e5ba49ef78cd4ba30f5480c95f49ea2377a18ce555180e0743254c337` |
| `case_fct_customer_event` | `generate_layer3_case_model` | `CASE_VIEW` | +49/-1 | `800897ac1b6fec4496e27a4a96987b108ddfe66577c03f985ad80d6f285545eb` | `ef716824f71aacd3323a02a4f37ff7e70c15c663f21d64d2da4568c209f338c9` |
| `case_fct_invoice` | `generate_layer3_case_model` | `CASE_VIEW` | +63/-1 | `730f204dd1564515b3cbafac4fff1134daac048a7c5c4f90a0811ce45433f5d6` | `a9294850bcaf12ca4e6619163b7e7ec264620e41b7e6adec4403ddcea4bbe62c` |

## Exact generation commands

### `customer_deletion_authorization_history`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model customer_deletion_authorization_history)" --profiles-dir . --no-use-colors
```

### `customer_deletion_authorizations`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model customer_deletion_authorizations)" --profiles-dir . --no-use-colors
```

### `customer_deletion_requests`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model customer_deletion_requests)" --profiles-dir . --no-use-colors
```

### `quarantine_customer_events`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model quarantine_customer_events)" --profiles-dir . --no-use-colors
```

### `quarantine_customer_services`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model quarantine_customer_services)" --profiles-dir . --no-use-colors
```

### `quarantine_invoices`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model quarantine_invoices)" --profiles-dir . --no-use-colors
```

### `stg_customer`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model stg_customer)" --profiles-dir . --no-use-colors
```

### `stg_customer_deletion_confirmations`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model stg_customer_deletion_confirmations)" --profiles-dir . --no-use-colors
```

### `stg_customer_events`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model stg_customer_events)" --profiles-dir . --no-use-colors
```

### `stg_customer_services`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model stg_customer_services)" --profiles-dir . --no-use-colors
```

### `stg_invoices`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer1_model --args "$(uv run --locked python scripts/regenerate_models.py args --model stg_invoices)" --profiles-dir . --no-use-colors
```

### `fa_pd_customer`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_priva_map_model --args "$(uv run --locked python scripts/regenerate_models.py args --model fa_pd_customer)" --profiles-dir . --no-use-colors
```

### `fa_pd_service_address`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_priva_map_model --args "$(uv run --locked python scripts/regenerate_models.py args --model fa_pd_service_address)" --profiles-dir . --no-use-colors
```

### `int_customer_deletion_plan`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_deletion_plan)" --profiles-dir . --no-use-colors
```

### `int_customer_event_resolution`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_event_resolution)" --profiles-dir . --no-use-colors
```

### `int_customer_events_keyed`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_events_keyed)" --profiles-dir . --no-use-colors
```

### `int_customer_events_resolved`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_events_resolved)" --profiles-dir . --no-use-colors
```

### `int_customer_protected`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_protected)" --profiles-dir . --no-use-colors
```

### `int_customer_service_resolution`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_service_resolution)" --profiles-dir . --no-use-colors
```

### `int_customer_services_keyed`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_services_keyed)" --profiles-dir . --no-use-colors
```

### `int_customer_services_resolved`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_customer_services_resolved)" --profiles-dir . --no-use-colors
```

### `int_invoice_resolution`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_invoice_resolution)" --profiles-dir . --no-use-colors
```

### `int_invoices_keyed`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_invoices_keyed)" --profiles-dir . --no-use-colors
```

### `int_invoices_resolved`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_invoices_resolved)" --profiles-dir . --no-use-colors
```

### `int_terminal_deleted_customer_keys`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer2_model --args "$(uv run --locked python scripts/regenerate_models.py args --model int_terminal_deleted_customer_keys)" --profiles-dir . --no-use-colors
```

### `dim_customer`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_model --args "$(uv run --locked python scripts/regenerate_models.py args --model dim_customer)" --profiles-dir . --no-use-colors
```

### `dim_date`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_model --args "$(uv run --locked python scripts/regenerate_models.py args --model dim_date)" --profiles-dir . --no-use-colors
```

### `dim_service`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_model --args "$(uv run --locked python scripts/regenerate_models.py args --model dim_service)" --profiles-dir . --no-use-colors
```

### `fct_customer_event`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_model --args "$(uv run --locked python scripts/regenerate_models.py args --model fct_customer_event)" --profiles-dir . --no-use-colors
```

### `fct_invoice`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_model --args "$(uv run --locked python scripts/regenerate_models.py args --model fct_invoice)" --profiles-dir . --no-use-colors
```

### `case_dim_customer`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_case_model --args "$(uv run --locked python scripts/regenerate_models.py args --model case_dim_customer)" --profiles-dir . --no-use-colors
```

### `case_dim_service`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_case_model --args "$(uv run --locked python scripts/regenerate_models.py args --model case_dim_service)" --profiles-dir . --no-use-colors
```

### `case_fct_customer_event`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_case_model --args "$(uv run --locked python scripts/regenerate_models.py args --model case_fct_customer_event)" --profiles-dir . --no-use-colors
```

### `case_fct_invoice`

```bash
DATABRICKS_CONFIG_PROFILE=bricksgdpr DBT_SEND_ANONYMOUS_USAGE_STATS=false DBT_PROJECT_CATALOG=bricksgdpr DBT_CONTROL_CATALOG=workspace DBT_CONTROL_SCHEMA=default uv run --locked dbt run-operation generate_layer3_case_model --args "$(uv run --locked python scripts/regenerate_models.py args --model case_fct_invoice)" --profiles-dir . --no-use-colors
```

## Validation results

The canonical and regenerated projects were built in separate schema families so the regression
did not replace the normal demo relations:

- canonical: `macroreg_base_d9003b_*`;
- regenerated: `macroreg_gen_d9003b_*`.

After the comparison and independent evidence review, all 12 isolated schemas were dropped with
`CASCADE`. The normal demo schemas and shared `priva_internal` function schema were retained.

Both projects ran the same live sequence with connection values supplied through the environment:

```bash
DBT_SCHEMA_PREFIX=<isolated-prefix> uv run --locked dbt build --full-refresh \
  --select '*' --exclude tag:access_control --profiles-dir . --no-partial-parse --no-use-colors
DBT_SCHEMA_PREFIX=<isolated-prefix> uv run --locked dbt run-operation apply_access_controls \
  --profiles-dir . --no-use-colors
DBT_SCHEMA_PREFIX=<isolated-prefix> uv run --locked dbt test --select tag:access_control \
  --profiles-dir . --no-use-colors
DBT_SCHEMA_PREFIX=<isolated-prefix> uv run --locked dbt build --select '*' \
  --profiles-dir . --no-use-colors
```

| Gate | Canonical | Regenerated |
| --- | ---: | ---: |
| Full refresh excluding access assertions | 375 pass, 0 warn, 0 error | 375 pass, 0 warn, 0 error |
| Access assertions after grant reconciliation | 4 pass, 0 warn, 0 error | 4 pass, 0 warn, 0 error |
| Complete unfiltered graph | 379 pass, 0 warn, 0 error | 379 pass, 0 warn, 0 error |

The first regenerated live attempt exposed a dbt log timestamp appended to generated SQL by the
artifact parser. The parser now removes boundary timestamps and rejects timestamp-only log lines in
either artifact. All 34 generation commands and all regenerated validation gates above were rerun
after that fix; the already-clean canonical baseline evidence was retained.

## Model-by-model live equivalence

The comparison covers all 28 persisted models. The six ephemeral models have no relations to query;
their SQL was compiled and exercised through downstream models and the complete test graph.

Each persisted relation was compared in both directions with `EXCEPT ALL`. Seven relations contain
runtime audit timestamps created with `current_timestamp()`; a column-level aggregate check proved
that the only raw differences were `detected_at`, `quarantined_at`, `suppression_recorded_at`, and
`mode_escalated_at`. After excluding only those runtime-generated audit fields, every relation has
zero differences in both directions and the same row count.

| Model | Canonical rows | Regenerated rows | Canonical minus regenerated | Regenerated minus canonical |
| --- | ---: | ---: | ---: | ---: |
| `case_dim_customer` | 0 | 0 | 0 | 0 |
| `case_dim_service` | 0 | 0 | 0 | 0 |
| `case_fct_customer_event` | 0 | 0 | 0 | 0 |
| `case_fct_invoice` | 0 | 0 | 0 | 0 |
| `customer_deletion_authorization_history` | 4 | 4 | 0 | 0 |
| `customer_deletion_authorizations` | 3 | 3 | 0 | 0 |
| `customer_deletion_requests` | 3 | 3 | 0 | 0 |
| `dim_customer` | 16 | 16 | 0 | 0 |
| `dim_date` | 1461 | 1461 | 0 | 0 |
| `dim_service` | 18 | 18 | 0 | 0 |
| `fa_pd_customer` | 15 | 15 | 0 | 0 |
| `fa_pd_service_address` | 17 | 17 | 0 | 0 |
| `fct_customer_event` | 30 | 30 | 0 | 0 |
| `fct_invoice` | 27 | 27 | 0 | 0 |
| `int_customer_deletion_plan` | 102 | 102 | 0 | 0 |
| `int_customer_events_resolved` | 30 | 30 | 0 | 0 |
| `int_customer_protected` | 15 | 15 | 0 | 0 |
| `int_customer_services_resolved` | 17 | 17 | 0 | 0 |
| `int_invoices_resolved` | 27 | 27 | 0 | 0 |
| `int_terminal_deleted_customer_keys` | 3 | 3 | 0 | 0 |
| `quarantine_customer_events` | 1 | 1 | 0 | 0 |
| `quarantine_customer_services` | 3 | 3 | 0 | 0 |
| `quarantine_invoices` | 11 | 11 | 0 | 0 |
| `stg_customer` | 21 | 21 | 0 | 0 |
| `stg_customer_deletion_confirmations` | 4 | 4 | 0 | 0 |
| `stg_customer_events` | 32 | 32 | 0 | 0 |
| `stg_customer_services` | 22 | 22 | 0 | 0 |
| `stg_invoices` | 39 | 39 | 0 | 0 |

## Evidence boundary

Textual differences are expected because the generator wraps bespoke business SQL in an explicit
source CTE and projection. The results above establish equality for the checked-in synthetic
fixtures, configured variables, execution identity, and recorded Databricks runtime. They do not
prove equality for arbitrary future inputs or replace production validation.
