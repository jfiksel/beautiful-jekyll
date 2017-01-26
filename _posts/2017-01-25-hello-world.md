---
layout: post
title: Hello World
subtitle: How I got my website and blog set up!
tags: [R, statistics, Jekyll, Github, Markdown]
---

Hey there and welcome to my blog! I hope to use this as a forum to post my thoughts on current trends in public health, statistics, and genomics, as well as a way to give useful tips for using R. In this first post, I want to let you know how I created this website with GitHub Pages/Jekyll and my setup for making posts with RStudio.

I decided to use the [Beautiful Jekyll template from Dean Attali](http://deanattali.com/beautiful-jekyll/) based off a recommendation from [Matt Cole](https://mattkcole.com). Getting it set up is extremely easy--make sure you have a [GitHub](https://github.com) account, click on the template link in the previous sentence, and follow his instructions. Once you have your own repository (i.e. followed the first two steps of Dean's instructions), I recommend cloning the repistory into your local computer to make changes. This reason for this is that you can use the command line to preview the site locally before pushing to your repo and publishing your work on the web. You can do this by first [downloading Jekyll](http://jekyllrb.com/docs/installation/), then simply enter the following code on the command line

``` bash
bundle exec jekyll serve
```

I made an alias for this (I called the command preview) so that I don't have to remember that command each time I want to preview my site. Once you are happy with your changes, commit them, and push to the Github repo.

Now for blogging. For each post, I plan to initially make [R Markdown](http://rmarkdown.rstudio.com), rather than [Markdown](http://daringfireball.net/projects/markdown/), files for my blog posts for two main reasons. First, I'm used to using [RStudio](https://www.rstudio.com) to create .Rmd documents for my analyses. Second, it's easier for me to integrate R code chunks and plots such as:

``` r
x <- c(rep(1, 10), 1:5, rep(5, 10), 9:13, 9:13, rep(11, 10))
y <- c(1:10, rep(5, 5), 1:10, rep(1, 5), rep(10, 5), 1:10)

plot(x,y, pch=19, xlab="", ylab = "", xaxt='n', yaxt='n')
```

![]({{ site.url }}/img/blog_images/hello-world_files/figure-markdown_github/hi-1.png)

The problem I run into with this is that Github pages currently only allows posts to be in the Markdown format. My current workflow, heavily borrowed from [Shirin](https://shiring.github.io/blogging/2016/12/04/diy_your_own_blog), to (somewhat efficiently) get around this is the following:

1.  Make a \_drafts directory in which you can develop all of your blog posts. I also recommend creating a directory called blog\_images inside of the img directory--more on this later
2.  In RStudio, create a new R Markdown file and set the default output format to HTML. This allows me to preview my post without having to constantly convert the file into Markdown and integrate it into my site. Save this inside of your \_drafts directory.
3.  Write a post!
4.  Once I am happy, I now want to change the output to a Markdown file. Replace the

``` r
output: html_document
```

line at the top of the R Markdown document with

``` r
output:
  md_document:
    variant: markdown_github
```

and then knit using RStudio. I now have to go into the .md document and add a header. For example, the header for this post is

``` r
---
layout: post
title: Hello World
subtitle: How I got my website and blog set up!
tags: [R, statistics, Jekyll, Github, Markdown]
---
```

If you made plots, like I did earlier, you'll also have to go to those locations in the .md document and edit it. For example, in the original .md document, the code used was:

``` r
![](hello-world_files/figure-markdown_github/hi-1.png)
```

You want to edit that to read

``` r
![]({{ site.url }}/img/blog_images/hello-world_files/figure-markdown_github/hi-1.png)
```

You may need to make some more manual changes, as the conversion from R Markdown to Markdown is not perfect. Read over your .md document before moving to the next step.


{:start="5"}
5.  Everything is in place and we simply have to move and rename some documents. Luckily, I've written a shell script that you can copy and use (mine is called make\_post.sh). It assumes that each .Rmd document corresponds to a different post. It copies the .md document corresponding to that post into the \_posts directory (renaming it with the date in front), as well as moving all of the files that were created after knitting your R Markdown file (such as your plots) into the blog\_images directory. I've set it up so that it only does this for new posts. If you want to make an update to a post, simply go into the status directory created by this script, and delete the corresponding file. Also, this may not work if you're on a Windows--sorry 'bout that!

``` bash
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
    touch $status_check
  #  echo $status_check
  fi
done
```

{:start="6"}
6.  Run the shell script, push your changes, and admire your post on your fancy new website!

I hope this was helpful! Please leave any comments or questions that you have, and I look forward to making more posts in the future.
