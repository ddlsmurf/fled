
# FlEd

`fled` lets you organise your files and folders in your favourite editor

## Introduction

`fled` enumerates a folder and its files, and generates a text listing.
You can then edit that listing in your favourite editor, and save changes.
`fled` then reloads those changes, and prints a shell script that would move
your files and folders around as-per your edits.

**You should review that shell script very carefully before running it.**

### Install

You can install using `gem install fled`.

### Philosophy

`fled` only generates text, it does not perform any operation directly.

The design optimises for making the edits very simple. This means that very small
edits can have large consequences, which makes this a **very dangerous** tool.
But so is `rm` and the rest of the shell anyway...

### Caveats

`fled` is only aware of files it scanned. It will not warn for overwrites,
nor use temporary files in those cases, etc.

`fled`'s editing model is rather complex and fuzzy. While there are some test
cases defined, any help is much appreciated.

You should be scared when using `fled`.

### Test status

[![Build Status](https://secure.travis-ci.org/ddlsmurf/fled.png?branch=master&this_url_now_ends_with=.png)](http://travis-ci.org/ddlsmurf/fled)

### Examples

Print help text and option list

    fled --help

Edit current folder

    fled

Edit all files directly in `path` folder

    fled -a path -d 0

Save default options

    fled --options > fled.config.yaml

Edit current folder using options

    fled --load fled.config.yaml

Add options to a command (`mkdir`, `mv`, `rm` or `rmdir`)

    fled | sed 's/^mv/mv -i/'

## Listing Format

    folder/                 :0
      file_one              :1
      folder_two/           :2
        file_three          :3

Each line of the listing is in the format `[indentation] name: uid`

- The *indentation* must consist of only spaces, and is used to indicate the parent folder
- The *name* must not use colons (`:`). If it is cleared, it is assumed the file/folder is to be deleted
  The *name* has a `/` appended if it is a directory.
- The *uid* is used by FlEd to recognise the original of the edited line. Do not assume a *uid* does not
  change between runs. It is valid only for the current run. Spaces before the *uid* are only cosmetic.

## Operations
### Creating a new folder

Add a new line (therefore with no uid):

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder/         :0
  new_folder
  folder_two/   :2
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mkdir folder/new_folder</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

### Moving

Change the indentation and/or line order to change the parent of a file or folder:

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder/          :0
  folder_two/    :2
    file_one       :1
    file_three   :3
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder/file_one folder/folder_two/file_one</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

*Moving an item below itself or its children is not recommended, as the listing may not be exhaustive*

### Renaming

Edit the name while preserving the uid to rename the item

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder_renamed/  :0
  file_one       :1
  folder_two/    :2
    file_changed :3
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder folder_renamed</code>
        </li>
        <li>
          <code>mv folder_renamed/folder_two/file_three folder_renamed/folder_two/file_changed</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

### Deleting

Clear a name but leave the uid to delete that item

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder_renamed/  :0
  :1
  :2
  :3
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder folder_renamed</code>
        </li>
        <li>
          <code>rm folder_renamed/folder_two/file_three</code>
        </li>
        <li>
          <code>rm folder_renamed/file_one</code>
        </li>
        <li>
          <code>rmdir folder_renamed/folder_two</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

### No-op

If a line (and all child-lines) is removed from the listing, it will have no operation.

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder/          :0
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <em>No operation</em>
    </td>
  </tr>
</table>

*Note that removing a folder without removing its children will move its children:*

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder/          :0
  file_one       :1
  file_three   :3
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder/folder_two/file_three folder/file_three</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

If an indent is forgotten:

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder/          :0
  file_one       :1
    file_three   :3
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder/folder_two/file_three folder/file_three</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

### All together

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                 :0
    file_one              :1
    folder_two/           :2
      file_three          :3
      </pre>
    </td>
    <td>
      <pre>
folder_new/          :0
  new_folder/
    first    :1
    second   :3
  :2
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder folder_new</code>
        </li>
        <li>
          <code>mkdir folder_new/new_folder</code>
        </li>
        <li>
          <code>mv folder_new/file_one folder_new/new_folder/first</code>
        </li>
        <li>
          <code>mv folder_new/folder_two/file_three folder_new/new_folder/second</code>
        </li>
        <li>
          <code>rmdir folder_new/folder_two</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

## Edge cases

These sort-of work, but are still rather experimental

### Swapping files

    folder/             :0
      file_one          :1
      file_two          :2

When applying

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/             :0
    file_one          :1
    file_two          :2
      </pre>
    </td>
    <td>
      <pre>
folder/        :0
  file_two   :1
  file_one   :2
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder/file_two folder/file_one.tmp</code>
        </li>
        <li>
          <code>mv folder/file_one folder/file_two</code>
        </li>
        <li>
          <code>mv folder/file_one.tmp folder/file_one</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

*Swapping file names may not work in cases where the generated intermediary file exists but was not included in the listing*

### Tree swapping

    folder/                      :0
      sub_folder/                :1
        sub_sub_folder/          :2
          file.txt               :3

When applying

<table>
  <tr>
    <th>
      <em>Original listing</em>
    </th>
    <th>
      <em>Edited listing</em>
    </th>
  </tr>
  <tr>
    <td>
      <pre>
  folder/                      :0
    sub_folder/                :1
      sub_sub_folder/          :2
        file.txt               :3
      </pre>
    </td>
    <td>
      <pre>
sub_sub_folder/  :2
  sub_folder/        :1
    folder/              :0
      file.txt       :3
      </pre>
    </td>
  </tr>
  <tr>
    <th colspan='2'>
      <em>Generates the script:</em>
    </th>
  </tr>
  <tr>
    <td colspan='2'>
      <ul>
        <li>
          <code>mv folder/sub_folder/sub_sub_folder sub_sub_folder</code>
        </li>
        <li>
          <code>mv folder/sub_folder sub_sub_folder/sub_folder</code>
        </li>
        <li>
          <code>mv folder sub_sub_folder/sub_folder/folder</code>
        </li>
        <li>
          <code>mv sub_sub_folder/file.txt sub_sub_folder/sub_folder/folder/file.txt</code>
        </li>
      </ul>
    </td>
  </tr>
</table>

## Changelog

*Version v0.0.3*

- Meta: Refactoring of code

*Version v0.0.2*

- Fix: Unreadable directories now ignored
- Fix: Version display and DRYed
- Fix: Moving files under files now moves up to parent folder of destination
- Meta: Travis-CI integration

*Version v0.0.1*

- First version

## Disclaimer

Warning: This is a very dangerous tool. The author recommends you do not
  use it. The author cannot be held responsible in any case.

## Contributors

- [Eric Doughty-Papassideris](http://github.com/ddlsmurf)

## Licence

[GPLv3](http://www.gnu.org/licenses/gpl-3.0.html)
