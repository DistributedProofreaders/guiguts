# kindlegen

KindleGen is a command line tool which enables publishers to work in an
automated environment with a variety of source content including HTML, XHTML
or EPUB. KindleGen converts this source content to a single file which supports
both KF8 and Mobi formats enabling publishers to create great-looking books
that work on all Kindle devices and apps.

Before mid-August 2020 Amazon included kindlegen as a stand-alone download. They
have since removed that and are instructing people to install the Kindle
Previewer.

https://www.amazon.com/gp/feature.html?docId=1000765261

## Packaging

We ship the older kindlegen binaries included with Guiguts 1.1.0 as a
convenience to the user. Future Guiguts versions will require the user to
download and install the Kindle Previewer.

### MacOS

The MacOS version of KindleGen is 32-bit only and it will not work on Catalina.

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
