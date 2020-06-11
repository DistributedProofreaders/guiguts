# kindlegen

KindleGen is a command line tool which enables publishers to work in an
automated environment with a variety of source content including HTML, XHTML
or EPUB. KindleGen converts this source content to a single file which supports
both KF8 and Mobi formats enabling publishers to create great-looking books
that work on all Kindle devices and apps.

https://www.amazon.com/gp/feature.html?docId=1000765211

## Packaging

We include the full kindlegen package contents extracted as a convenience to
the user.

### MacOS

As of 2020-06-17 the MacOS version of KindleGen at the link above is 32-bit
only, meaning it will not work on Catalina.

You will get the following error if you try to run this version of `kindlegen`
on Catalina or later:
```
-bash: ./kindlegen: Bad CPU type in executable
```

To get a working version of KindleGen for Catalina and later, install the
[Kindle Previewer](https://smile.amazon.com/gp/feature.html/ref=amb_link_4?docId=1000765261)
which includes it. For Kindle Previewer 3 the file is at
`/Applications/Kindle Previewer 3.app/Contents/lib/fc/bin` and can be copied
over the version bundled with Guiguts.
