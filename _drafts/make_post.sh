#!/bin/bash
echo Which file do you want to post?
read -e -p "Post:" file
file="${file}.Rmd"
post=${file//.Rmd}
markdown="${post}.md"
header="${post}-header.md"
echo Do you want to add a header? Enter y or n
read header_y_n
if [ $header_y_n == "y" ]
then
  cp $header temp_post.md
  cat $markdown >> temp_post.md
  mv temp_post.md $markdown
fi
perl -pi -e 's/..\/img\/blog_images\///g' $markdown
perl -pi -e 's/!\[]\(/!\[]\(\{\{site_url\}\}\/img\/blog_images\//g' $markdown
post_files="${post}_files"
date=`date +%Y-%m-%d`
markdown_for_post="${date}-${markdown}"
wd=$PWD
cd ../_posts/
if [ -f *${markdown} ]
then
  markdown_for_post=*${markdown}
fi
cd $wd
markdown_output="../_posts/${markdown_for_post}"
cp $markdown $markdown_output
cp -r $post_files ../img/blog_images

if diff $markdown_output $markdown >/dev/null; then
  echo "Your post was succesfully moved";
else
  echo "There was an error in moving your post";
fi
