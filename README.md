# Reverse-SitecoreWDP

**Reverse Sitecore Web Deploy Package** is a standard, well known zip package created in old format (before `.scwdp` era).

```
Sitecore X.Y rev. ZZZZZZ.zip
├── Sitecore X.Y rev. ZZZZZZ (folder)
│   ├── Data
│   ├── Databases
│   ├── Website
```

It is called reverse because it is created out of `.scwdp` file.

## Demo

![reverse-demo](https://user-images.githubusercontent.com/6848691/70654641-0338ad80-1c57-11ea-8bd5-c8af31d3b42f.gif)

## How to use

1. Clone repository
```
git clone https://github.com/alan-null/reverse-scwdp.git
```

2. Create configuration file (use example `configuration.example.json`)

3. Store Sitecore WDP zip file in the repository root.

4. Run `main.ps1`

Once the process is done you will notice a file with `.1click` extension.

This is a **Reverse-SitecoreWDP**
