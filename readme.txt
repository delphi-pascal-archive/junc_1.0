Junc.exe - Junction creation and listing utility
------------------------------------------------
This program is similar to Junction.exe utility by Mark Russinovich,
http://www.sysinternals.com. It's just ported from Mark's C source
to Delphi, so Delphi programmers are able to use junction creation/listing
code in their projects. Works under Windows 2000/XP. Freeware.

Disclaimer
----------
This software is provided "as is", without any guarantee made as to its
suitability or fitness for any particular use. It may contain bugs, so
use of this tool is at your own risk. I take no responsilbity for any
damage that may unintentionally be caused through its use.

Notes
-----
1. "Recurse subdirectories" option is not implemented.
2. Before creating a junction, program tests target volume for
   "Reparse points supported" flag.
3. Source code can be compiled with Delphi 4 - 7.


Copyright (C) 2006 Alexey Torgashin
http://alextpp.narod.ru
atorg@yandex.ru
