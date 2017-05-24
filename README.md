# Tumblr-Reblogs

Ever wanted to know where a Tumblr blog gets its photos/videos from or who reblogs them? Using the [Tumblr API v2](https://www.tumblr.com/docs/en/api/v2), this script reads the notes to photo/video posts and prints two sorted lists of “reblogged from” and “reblogged by” blog names.

At first I wanted to visualize the result with GraphViz but then found that plain old text output is more meaningful.

Requirements:
* [jq command-line JSON processor](https://stedolan.github.io/jq/) (version 1.5 or later)
* [GNU Parallel](https://www.gnu.org/software/parallel/) (version 20131122 or later)

Limitations:
The API only returns 50 notes maximum, for details and workarounds see [this stackoverflow question](https://stackoverflow.com/questions/14415592/how-can-i-see-all-notes-of-a-tumblr-post-from-python). This is why the "reblogged by" list is by far not complete.
