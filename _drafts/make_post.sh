#!/bin/bash
if [ ! -d ./status ]
then
    mkdir status
fi
for file in *.Rmd; do
  post=${file//.Rmd}
  markdown="${post}.md"
  post_files="${post}_files"
  date=`date +%Y-%m-%d`
  markdown_for_post="${date}-${markdown}"
  status_check="./status/${post}.ck"
  markdown_output="../_posts/${markdown_for_post}"
  if [ ! -f $status_check ]
  then
    cp $markdown $markdown_output
    cp -r $post_files ../img/blog_images
    #touch $status_check
  #  echo $status_check
  fi
done
