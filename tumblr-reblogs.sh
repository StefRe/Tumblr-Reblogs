#!/bin/bash
## Gets reblog and notes info for a tumblr blog and compiles two lists
## "reblogged from" and "reblogged by" for the post of this blog

# key taken from tumblr API
tumblr_app_key=lLgaViMwaj2FzUMnWTODDgbSKhINLO3bPfRF5yF9J1iN4v4Eg5

if [ -z $1 ]; then
    echo "Usage: $0 blog [type]"
    exit
fi
tumblr_blog_name=${1%%.*}
tumblr_blog_name=${tumblr_blog_name##*/}

# set post type
if [[ "$2" =~ ^(text|quote|link|answer|video|audio|photo|chat)$ ]]; then
    post_type=$2
else
    if [ -n $2 ]; then
       echo $0: "Unknown post type $2, using photo instead"
    fi
    post_type=photo
fi


# check for jq version 1.5 or later
which jq >>/dev/null
if [ $? -ne "0" ]; then
    echo "jq (stedolan.github.io/jq) required."
    exit
fi
jq_version=$({ jq --version; } 2>&1)
if [ "${jq_version##*.}" -lt 5 ]; then    ## assuming major version being 1
    echo "jq version 1.5 or later required, found $jq_version"
    exit
fi


# get first 20 posts and total number of posts
wget -q -4 -O - "http://api.tumblr.com/v2/blog/$tumblr_blog_name.tumblr.com/posts/$post_type?api_key=$tumblr_app_key"`
                 `"&filter=text&reblog_info=true&notes_info=true&offset=0" > $tumblr_blog_name.$post_type.posts
tumblr_total_posts=$(jq '.response | .blog | .total_posts' $tumblr_blog_name.$post_type.posts 2>/dev/null)
tumblr_total_posts=${tumblr_total_posts:-0}
echo $tumblr_total_posts posts total
[ $tumblr_total_posts -eq 0 ] && exit


# really get all posts if there are many?
if [ $tumblr_total_posts -gt 1000 ]; then
    read -p "How many posts to read [$tumblr_total_posts]: " tumblr_posts_to_read
    tumblr_posts_to_read=${tumblr_posts_to_read:-$tumblr_total_posts}
    if [ $tumblr_posts_to_read -lt $tumblr_total_posts ]; then
        echo reading $tumblr_posts_to_read of $tumblr_total_posts posts
        tumblr_total_posts=$tumblr_posts_to_read
    fi
fi


# download remaining posts
if [ $tumblr_total_posts -gt 20 ]; then
    parallel --bar -j 8 "wget -q -4 -O - http://api.tumblr.com/v2/blog/$tumblr_blog_name.tumblr.com/posts/$post_type"`
                        `"?api_key=$tumblr_app_key\&filter=text\&reblog_info=true\&notes_info=true\&offset={1}" ::: \
                        $(seq 20 20 $tumblr_total_posts) >> $tumblr_blog_name.$post_type.posts
fi


# reblogged by
jq --arg blog $tumblr_blog_name '.response.posts[] | try .notes[] | select(.type == "reblog") | '`
     `'select(.reblog_parent_blog_name == $blog) | .blog_name' $tumblr_blog_name.$post_type.posts | sort | \
     uniq -c | sort -n -r | tr -d '"' > $tumblr_blog_name.reblogged_by


# reblogged from (don't use .reblogged_from_name as it's null for private blogs)
jq '.response.posts[].reblogged_from_uuid | rtrimstr(".tumblr.com")' $tumblr_blog_name.$post_type.posts | sort | \
   uniq -c | sort -n -r | tr -d '"' > $tumblr_blog_name.reblogged_from


# number of original posts
tumblr_total_posts=$(jq '.response.posts | length' $tumblr_blog_name.$post_type.posts | awk '{s+=$1} END {print s}')
tumblr_original_posts=$(sed -n '/null/ s/ *\([0-9]*\) null/\1/p' $tumblr_blog_name.reblogged_from)
if [ -z "${tumblr_original_posts}" ]; then
    tumblr_original_posts=0
fi

# reblog roots
echo -e '\n        reblog roots' >> $tumblr_blog_name.reblogged_from
jq '.response.posts[].reblogged_root_uuid | rtrimstr(".tumblr.com")' $tumblr_blog_name.$post_type.posts | sort | \
   uniq -c | sort -n -r | tr -d '"' >> $tumblr_blog_name.reblogged_from


# print the two lists side by side with a header
echo -e "$tumblr_blog_name: $tumblr_total_posts $post_type posts, $tumblr_original_posts of which original (non-reblogged)\n"\
     > $tumblr_blog_name.reblog
echo '        reblogged from		    	                            reblogged by' >> $tumblr_blog_name.reblog
pr -w 120 -m -t <(grep -v null $tumblr_blog_name.reblogged_from) $tumblr_blog_name.reblogged_by | expand >> $tumblr_blog_name.reblog


# convert to html
sed -f - $tumblr_blog_name.reblog > $tumblr_blog_name.html << SED_SCRIPT
1 { i\
<!doctype html>\
<html lang=en>\
<head>\
<meta charset=utf-8>
  s!\([^ ]\+\): \(.*$\)!<title>\1 reblogging</title>\
<\/head>\
<body>\
<pre>\
<b><h2>\1</h2>\2<\/b>!
}
2,$ s!\([0-9]\+ \)\([^ ]\+\)!\1<a href="http://\2.tumblr.com/archive/filter-by/$post_type">\2</a>!g
2,$ s!\(reblogged by\|reblogged from\|reblog root\)!<b>\1</b>!g
$ a\
</pre>\
</body>\
</html>
SED_SCRIPT

# clean up
rm $tumblr_blog_name.reblogged_by  $tumblr_blog_name.reblogged_from $tumblr_blog_name.reblog

# open result in default application
xdg-open $tumblr_blog_name.html

