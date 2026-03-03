# Third-Party Notices

This project is a native macOS front-end that invokes external camera tooling.
It does not vendor or redistribute third-party source code by default, but it depends on and is inspired by the projects listed below.

## 1) gphoto2

- Project: [gphoto2](https://github.com/gphoto/gphoto2)
- Website: [gphoto.org](http://www.gphoto.org)
- Source archive: [SourceForge gPhoto files](https://sourceforge.net/projects/gphoto/files/)
- Copyright: Marcus Meissner and gPhoto contributors
- Upstream license: GNU General Public License, Version 2 (GPL-2.0)
- Local license copy: [licenses/GPL-2.0.txt](licenses/GPL-2.0.txt)

Credit note:
- gPhoto Studio uses the `gphoto2` executable as the camera backend.
- Users are responsible for installing `gphoto2` and complying with its license terms when redistributing binaries/packages that include it.

## 2) digiCamControl

- Project: [digiCamControl](https://sourceforge.net/projects/digicamcontrol/)
- Upstream repository: [dukus/digiCamControl](https://github.com/dukus/digiCamControl)
- Copyright: Duka Istvan
- Upstream license: MIT License
- Local license copy: [licenses/digiCamControl-MIT.txt](licenses/digiCamControl-MIT.txt)

Credit note:
- gPhoto Studio adopts workflow ideas inspired by digiCamControl (preset-driven capture, queue-based status, timelapse/tether patterns).
- No direct digiCamControl source code is bundled in this repository unless explicitly stated in future commits.

## 3) Optional Build-Time Library (Icon Generation)

- Package: [Pillow](https://python-pillow.org/)
- Usage in this repository: optional; only used by `scripts/generate-icon-assets.sh` to draw default icon art.
- License: see Pillow project licensing documentation.

## Compliance Summary

- This repository's own source code is released under the `MIT` license (see [LICENSE](LICENSE)).
- Third-party tools retain their own licenses and copyright.
- Keep this notice file when redistributing this project.

## Included MIT Notice (digiCamControl)

The following notice is included verbatim from upstream for compliance completeness:

```
digiCamControl - DSLR camera remote control open source software Copyright (C) 2014 Duka Istvan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
