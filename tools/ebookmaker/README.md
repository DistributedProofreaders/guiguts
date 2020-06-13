# EBookMaker

EBookMaker is the tool used to convert projects into EPUB and Kindle files
for use with Project Gutenberg.

https://github.com/gutenbergtools/ebookmaker

## Windows

We bundle a Windows binary of ebookmaker manually created by the 
[ebm_builder](https://github.com/DistributedProofreaders/ebm_builder) tool.

### Installing the python version manually

_These instructions are for advanced users. You do not need these steps to use
the `ebookmaker.exe` file._

We ship a binary because while the tool is a simple python script, the build
environment needed for the script's dependencies is very involved. However,
if you want the latest version of ebookmaker without waiting for a new build
here's how you can do it.

1. Install all of the Windows build dependencies. This is covered in step 2 of the
   [ebm_builder](https://github.com/DistributedProofreaders/ebm_builder/blob/master/README.md)
   instructions.
2. Install ebookmaker by starting a command line window and running:
   ```
   pip3 install --user ebookmaker
   ```

To run ebookmaker:
```
python "%APPDATA%\Python\Python38\Scripts\ebookmaker" --version
```

## MacOS

EBookMaker installs easily on MacOS with the Python 3 and Cairo included with
[Homebrew](https://brew.sh). After installing Homebrew:

```
brew install python3
brew pin python3
brew install cairo
```

Then install EBookMaker:

```
pip3 install --user ebookmaker
```

The script to start ebookmaker will be placed into your user's local Python
package directory which will not be on your path. You can add it to path by
updating your shell's profile. We've included a helpful script since the
shell profile can change depending on your version of MacOS.

```
./add_ebookmaker_to_path.sh
```

After closing and reopening a terminal window, `ebookmaker` should be on your
path and usable. You can confirm this with:

```
ebookmaker --version
```

To update ebookmaker to the latest version, use:

```
pip3 install --user --upgrade ebookmaker
```

### Notes and troubleshooting

As of this writing, Homebrew installs Python 3.7. If Homebrew installs a later
version (eg: 3.8) you will need to adjust the path above to point to the
correct location. Use `python3 --version` to see what version of python has
been installed.

EBookMaker requires Python 3.6 or later. If you have earlier versions of
Python installed via Homebrew, you may get errors unless you uninstall them
first.
