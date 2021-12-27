# DoubleFine Explorer  
Version 1.4<br>By Bennyboy<br>[Quick and Easy Software](http://quickandeasysoftware.net/)

 An explorer tool for games by Double Fine Productions. It supports games that use the Moai, Buddha and Remonkeyed engines. That's most games the company has released.
 
It enables you to view, extract and convert resources. This includes text, speech, music, scripts and images. 
  

## New in this version
 - Added support for the ppf level pack bundles in Psychonauts 1. Many thanks to [John Peel](https://github.com/JohnPeel/repkg/wiki/PPF-File-Format) for excellent his work on reverse engineering the new format. 
This means that the newer Steam/GOG versions of the game are now fully supported. Anyone needing to look inside the Xbox or PS2 versions or indeed browse the level pack files in the original release can still use my old [Psychonauts Explorer.](http://quickandeasysoftware.net/software/psychonauts-explorer)  program.

## How to use it

-   Click **Open** and either click on **open folder** or choose one of the games and the game folder will automatically be found. Choose one of the resource files.
  
-   Click **Save File** to save a file. Different options will appear here depending on the type of file you've selected.
  
-   Click **Save All Files** to save all files. Different options will be available here depending on the type of files available in the currently open resource file.
  

### Filtering the files:

-   Click on the **View** button to show a list of all the different file types, selecting one of these changes the view so that only these file types are visible.
  
-   To reset the view and show all files, click the button again and click **View All Files**.

### Searching the files:

-   To search just type in the search box. Searching ignores any filter that you've used. I.e. the view will be reset to 'All Files'. The search looks in file names and is an 'instant search' - the search happens as you type.
  
-   To reset the view either delete the text in the search box or click the **View** button and select **View all files**.

### Extra hidden stuff:
There is a hidden button that can automatically extract a file and open it in a hex editor.  
To enable this feature you need to make a DoublefineExplorer.ini file in the same place as the program. Inside it should look like this:  

    [Settings]  
    Hexeditor=C:\\Program Files\\BreakPoint Software\\Hex Workshop v6\\HWorks32.exe  

  
Obviously Hexeditor should point to the path of your chosen hex editor.  
  
When the ini file is present the **Send to Hex Ed** button will appear. Files that are sent to the hex editor are first dumped to the temp folder. The program keeps track of what files it has saved here and when you open a new file or close the program it will delete them (though it obviously cant delete any files that are still open in the hex editor so close that first).  
 

## What games are supported? 
The pc versions of the following games are supported. Versions for other platforms usually work but are largely untested.

-   Broken Age
-   Brutal Legend
-   Costume Quest
-   Costume Quest 2
-   Day of the Tentacle Remastered
-   Full Throttle Remastered
-   Grim Fandango Remastered
-   Headlander
-   Iron Brigade
-   Massive Chalice
-   Psychonauts 1 (The newer version that's on Steam and GOG. See the Limitations section below for more information).
-   Stacking
-   The Cave
-   The Amnesia Fortnight prototypes seem to work but aren't really tested


## Limitations and bugs

- Psychonauts 1: The new version of Psychonauts 1 that's on Steam and GOG changed the format of the level pack files (.ppf). DoubleFine Explorer only supports this newer version, If you have the original version you can open all the level files in [Psychonauts Explorer.](http://quickandeasysoftware.net/software/psychonauts-explorer)
  
- There are a few audio files that don't decode correctly. This is probably because they use a different codec. There are known problems with UI.fsb in The Cave and with 5 fsb files in Iron Brigade.  
  
- Grim Fandango Remastered: I've concentrated on adding support for the newer stuff introduced in the Remastered version. The original files can still be decoded with [SCUMM Revisited.](https://quickandeasysoftware.net/the-vault)



## Source 
Available from my [Github.](https://github.com/bgbennyboy/DoubleFine-Explorer)

## Licence 
This program and its source is released under the terms of the [Mozilla Public License v. 2.0.](https://www.mozilla.org/MPL/2.0/)

## Thanks
- [Jimmi Thøgersen (Serge)](http://www.jither.net/) for his Vima decoding code.  
- [Luigi Auriemma](http://aluigi.altervista.org) for infomation on FSB files.  
- Oliver Franzke for being kind enough to solve the mystery of how images are encoded in DOTT.  

## Support:  
[Contact me](http://quickandeasysoftware.net/contact).  
  
All my software is completely free. If you find this program useful please consider making a donation. This can be done on my [website](http://quickandeasysoftware.net).

## Disclaimer:  
The software is provided "as-is" and without warranty of any kind, express, implied or otherwise, including without limitation, any warranty of merchantability or fitness for a particular purpose. In no event shall the initial developer or any other contributor be liable for any special, incidental, indirect or consequential damages of any kind, or any damages whatsoever resulting from loss of use, data or profits, whether or not advised of the possibility of damage, and on any theory of liability, arising out of or in connection with the use or performance of this software.  

<br><br>
Last updated 27/12/21
