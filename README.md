# sqlite3.zig

[![](https://img.shields.io/badge/ziglang-orange.svg?labelColor=F7A41D&color=F7A41D&logoColor=fff&style=for-the-badge&logo=Zig)](https://ziglang.org)
[![](https://img.shields.io/badge/sqlite3-orange.svg?labelColor=003B57&color=003B57&logoColor=fff&style=for-the-badge&logo=sqlite)](https://sqlite.org)

**`sqlite3.zig`** is a minimal, non-opinionated [`sqlite3`](https://sqlite.org) driver for [`ziglang`](https://ziglang.org).

## Overview

`sqlite3.zig` provides an easy interface to `sqlite3` that allows you to build both applications and [`sqlite3` runtime extensions](loadext.html).

## Setup

- You need to download the [`sqlite3` amalgamation file](https://www.sqlite.org/amalgamation.html) and extract it inside your project 
(say under `$PROJECT/sqlite3` directory).  

  The library follows a _Bring-Your-Own_ model when it comes to bundling `sqlite3`. You are expected 
to provide necessary configuration by setting up appropriate include paths etc. This may sound difficult but is extremely easy and allows 
you to better manage `sqlite3` version (rather than depend on us to update it 😉).

- Update your `build.zig` file to add `$PROJECT/sqlite3` to your include path, and also add a dependency on `sqlite3.c` source file.

  ```zig
  exe.addIncludeDir("sqlite3/");
  exe.addCSourceFile("sqlite3/sqlite3.c", &[_][]const u8 {
    // any compile-time flags that you might want to add
    // see: https://www.sqlite.org/compile.html
  });
  ```
  
  This would allow `#include <sqlite3.h>` to resolve to `$PROJECT/sqlite3/sqlite3.h` and also include `sqlite3.c` source along with your application.
  
- To add `sqlite3.zig` to your project add it as a git submodule (say at `$PROJECT/libs/sqlite3`)

  ```zig
  exe.addPackagePath("sqlite3.zig", "libs/sqlite3/sqlite3.zig");
  ```
  
 You can now do `@import('sqlite3.zig')` and start enjoying `sqlite3` 😁
 
 ## License

MIT License Copyright (c) 2022 Riyaz Ali

Refer to [LICENSE](./LICENSE) for full text.
 
