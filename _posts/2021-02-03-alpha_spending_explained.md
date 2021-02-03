---
layout: post
title: Introduction to Conducting Interim Analyses Using Alpha Spending
tags: [Clinical Trials, Alpha Spending, Group Sequential, R]
---
<style TYPE="text/css">
code.has-jax {font: inherit; font-size: 100%; background: inherit; border: inherit;}
</style>
<script type="text/x-mathjax-config">
MathJax.Hub.Config({
    tex2jax: {
        inlineMath: [['$','$'], ['\\(','\\)']],
        skipTags: ['script', 'noscript', 'style', 'textarea', 'pre'] // removed 'code' entry
    }
});
MathJax.Hub.Queue(function() {
    var all = MathJax.Hub.getAllJax(), i;
    for(i = 0; i < all.length; i += 1) {
        all[i].SourceElement().parentNode.className += ' has-jax';
    }
});
</script>
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.4/MathJax.js?config=TeX-AMS_HTML-full"></script>


In confirmatory (phase III) clinical trials, the goal is to test whether an experimental
treatment is superior to a standard of care or placebo treatment. In designing the trial, health authorities require that type I error is strictly controlled--that is, if the experimental treatment is truly not better than the control treatment, we want to limit the probability
of declaring success to being no more than some value $\alpha$ (typically $\alpha = .05$).

However, phase III trials are usually very large and very expensive, and sponsors
benefit by making the trial as short and as small as possible. One way we could do that
is by performing a statistical test to see if the treatment is effective halfway through the trial. This is called an interim analysis. If we see a statistically significant treatment effect, we stop the trial very early and save money by not having to enroll
the remaining patients, and we get the drug out to patients faster. If not, we
will just wait until all of the patients have enrolled, like we would have without
this interim analysis.

How exactly would we perform this interim analysis? Well, health authorities want
to have strict control of type I error--this corresponds to declaring success
if our p-value is less than .05 at the end of the trial. So what our type I error be if we decided to declare success if our p-value at the interim analysis was also less than .05? Let's find out through simulation.

We will assume that we have a binary endpoint and that our original plan was to enroll
500 patients, randomized 1:1 to the treatment and control arm. Let's assume that patients
taking the drug used for the control arm have a 20% chance of responding to the treatment.
To find the type I error of our design, we will simulate data by assuming that
patients taking the treatment drug also have a 20% chance of responding to the treatment. We
will perform an interim analysis after we have enrolled 250 patients, and if we do not
declare success, we will perform a final analysis after we have enrolled all 500
patients. In our simulation, we will use z-scores to declare success: a p-value of
less than .05 is equivalent to obtaining a z-score $z$ such that $|z| > 1.96$


```r
### Function to get zscore
get_z <- function(resp, trt) {
    p0 <- mean(resp[trt == 0])
    p1 <- mean(resp[trt == 1])
    n0 <- sum(trt == 0)
    n1 <- sum(trt == 1)
    sd <- sqrt(p1 * (1 - p1) / n1 + p0 * (1 - p0) / n0)
    z <- (p1 - p0) / sd
    return(z)
}
    
### Set our seed
set.seed(123)
### Number of simulations
Nsims <- 10000
### keep track of of zscores for interim and final analysis
z_scores <- matrix(NA, nrow = Nsims, ncol = 2)
### Numebr of subjects at final and interim analysis
Ntotal <- 500
Ninterim <- Ntotal / 2
for(i in 1:Nsims) {
    ### treatment indicator
    trt <- rep(0:1, Ntotal / 2)
    ### Response probabilities for control and treatment
    ### They are the same because this is simulating under the null
    resp_prob <- rep(NA, Ntotal)
    resp_prob[trt == 0] <- .2
    resp_prob[trt == 1] <- .2
    ### Actual response
    resp <- rbinom(Ntotal, 1, resp_prob)
    ### z score for interim
    z_interim <- get_z(resp[1:Ninterim], trt[1:Ninterim])
    ### z score for final
    z_final <- get_z(resp, trt)
    ### Do we reject at either the interim or final analysis
    z_scores[i, 1] <- z_interim
    z_scores[i, 2] <- z_final
}
### Type 1 error
### Get cutoff for rejection (this is approximately 1.96)
cutoff <- qnorm(.975)
### Check for each simulation whether we rejected at either interim or final analysis
reject <- rep(NA, Nsims)
for(i in 1:Nsims) {
    reject[i] <- abs(z_scores[i,1]) > cutoff | abs(z_scores[i,2]) > cutoff
}
type_1_error <- mean(reject)
type_1_error
```

```
## [1] 0.0872
```

We see from above that our type I error is actually 0.087--
more than the .05 level that health authorities are willing to accept! Our
naive strategy clearly led to an inflated type I error, and if we had decided
to do more than 1 interim analysis, the type I error would have been even higher. Thus,
we need a more principled strategy.

This is where the idea of alpha spending comes in. Under the null hypothesis
of no treatment effect, we want the probability of rejecting our null hypothesis
at ANY of the interim analyses to be .05. Formally, if we performed an interim and
a final analysis, and got z-scores $z_{1}$ and $z_{2}$, we would reject our null hypothesis at the first interim analysis of $|z_{1}| > c_{1}$ (for some cutoff $c_{1}$), and similarly we would reject our null hypothesis at the final analysis if $|z_{2}| > c_{2}$ (and $|z_{1}| \leq c_{1}$, which we would need in order to even be performing a final analysis). Thus, we want
$P(|z_{1}| > c_{1} \mbox{ OR } |z_{1}| \leq c_{1} \mbox{ & } |z_{2}| > c_{2}) = .05$.

So how exactly do we determine these cutoffs? Other than the constraint of the
type-I error above, we actually have quite a lot of latitude. In the single interim
analysis example, we first have to decide on our type I error for the first interim analysis--that is, under the null, the probability of seeing $|z_{1}| > c_{1}$. We could pick .025, in which case we have $c_{1} = 2.24$. Or we might say that we only want to stop
at the interim analysis if we see a very strong effect, and pick .01, in which case $c_{1} = 2.58$. But let's stick with .025. How do we then determine $c_{2}$? One might think
that the cutoff $c_{2}$ would also be 2.24, corresponding to a p-value of  .05 - .025 = .025. That is, if we don't declare success at the first interim, we've "spent" our first interim analysis alpha of .025, and thus have .025 left over. However, let's look at a plot
of the z-score from the first interim analysis versus the final analysis from the earlier simulation:


```r
plot(z_scores[,1], z_scores[,2], xlab = "Z-score IA", ylab = "Z-score FA")
```

![]({{site_url}}/img/blog_images/alpha_spending_explained_files/figure-html/plot_zscores-1.png)<!-- -->

We see that they're actually correlated! This is unsurprising, because all of the patients used to calculate the z-score for the first interim analysis are also used the calculate the z-score in the final analysis. What exactly is the correlation?


```r
z_score_cor <- cor(z_scores[,1], z_scores[,2])
round(z_score_cor, 3)
```

```
## [1] 0.711
```

Interestingly, this is very close to $\sqrt{.5}$--and in fact, the theoretical
correlation between these two z-scores is exactly $\sqrt{.5}$. Why exactly this value? Because we did the interim analysis exactly halfway through our trial. If we had done the interim analysis 20% of the way through the trial, the correlation would have been $\sqrt{.2}$. And if we did two interim analyses--one at 20%, and one at 50%--then the correlation between the z-scores for these two interim analyses would have been $\sqrt{.2 / .5}$. Thus, we have
to take this correlation into account when we calculate $c_{2}$. However, this
involves quite a bit of calculus. Luckily, we have the R package `rpact` that can calculate this cutoff for us:


```r
library(rpact)
design <- getDesignGroupSequential(sided = 2, alpha = 0.05, beta = 0.2,
informationRates = c(0.5, 1), typeOfDesign = "asUser", userAlphaSpending = c(.025, .05))
### Boundaries (c1 and c2) for design
design$criticalValues
```

```
## [1] 2.241403 2.125119
```

```r
### pvalues for design
design$stageLevels * 2
```

```
## [1] 0.0250000 0.0335767
```

We actually see that we can reject the null hypothesis at the final analysis if we obtain a p-value of less than .034, rather than using a value of .025. We can now recalculate our type I error from the previous simulation with these new boundaries:


```r
### Check for each simulation whether we rejected at either interim or final analysis
reject <- rep(NA, Nsims)
cutoffs <- design$criticalValues
for(i in 1:Nsims) {
    reject[i] <- abs(z_scores[i,1]) > cutoffs[1] | abs(z_scores[i,2]) > cutoffs[2]
}
type_1_error <- mean(reject)
type_1_error
```

```
## [1] 0.0523
```

Our type I error rate for this trial design is now closer to .05, although not exactly .05 due to simulation error. 

Lan and DeMets (Statistics in Medicine, 1994) generalized this approach in what they call alpha spending. One can conduct any number of interim analyses throughout the trial, as long as they specify what is called an alpha spending function. This alpha spending function, denoted $\alpha(t)$, is a non-decreasing function of the information fraction $t$--that is, the fraction of the total sample size (or total number of events for event driven trials). $\alpha(1)$ must be the type I error of the whole trial. In our example, we had $\alpha(.5) = .025$ and $\alpha(1) = .05$. If we plan on doing $K$ total analyses ($K-1$ interim analyses, and 1 final analysis), and information fractions $t_1, t_2, \ldots, t_K = 1$,  then the probability of rejecting the null hypothesis (if the null hypothesis is true) at the first interim analysis is $\alpha(t_1)$. The probability under the null of not rejecting at the first interim, but at the second interim, is $\alpha(t_2) - \alpha(t_1)$, and so the probability of rejecting at either first or second interim is $\alpha(t_2)$. We can continue this logic until we reach $\alpha(t_K)$, which is our type-I error of rejecting the null hypothesis (when the null is true) at any point in the trial. If we pre-specify our information fractions and our alpha spending function, we can use the `rpact` package to get our cutoffs used for each analysis, $c_1, \ldots, c_K$. 

There are infinitely many alpha spending functions we could use. However, the two
most commonly used spending functions are the O'Brien-Fleming (OBF) and Pocock spending functions.
We can illustrate the difference between the two by plotting the stopping boundaries for
a trial with interim analyses at 20%, 40%, 60%, 80%, and 100% information fractions:


```r
design_obf <- getDesignGroupSequential(sided = 2, alpha = 0.05, beta = 0.2,
informationRates = seq(.2, 1, by = .2), typeOfDesign = "asOF")
design_pocock <- getDesignGroupSequential(sided = 2, alpha = 0.05, beta = 0.2,
informationRates = seq(.2, 1, by = .2), typeOfDesign = "asP")
boundary_df <- data.frame(critical_values = c(design_obf$criticalValues, design_pocock$criticalValues),
                          spending_function = rep(c('OBF', 'Pocock'), each = 5),
                          t = rep(seq(.2, 1, by = .2), 2))
library(ggplot2)
ggplot(boundary_df, aes(x = t, y = critical_values, color = spending_function)) +
    geom_line() +
    geom_point() +
    labs(x = "Information Fraction", y = "Critical Value", color = "Spending Function")
```

![]({{site_url}}/img/blog_images/alpha_spending_explained_files/figure-html/obf_vs_pocock-1.png)<!-- -->

We can see a big difference between these two spending functions. The OBF spending
function requires a large z-score to declare significance early on in the trial,
and these boundaries decrease as the information fraction increases, with the final
cutoff $c_K$ being very close to the level of 1.96 we started with if we did not
perform interim analyses. The Pocock spending function corresponds to using
approximately equal cutoffs for each analysis. The OBF spending function is more commonly
used (at least in my experience), because 1) we want to only stop early with a smaller sample size if we have an extremely convincing effect size estimate and 2) If we were to not
succeed in the interim analyses, we have a smaller hurdle for the final analysis.

The idea of an alpha spending function is incredibly important for clinical trials. 
All of the major phase III trials for coronavirus vaccines used alpha spending so that
they could conduct multiple interim analyses without inflating the type I error. Thus, I hope that this gave a (slightly technical) introduction and intuition on how we can do principled interim analyses using alpha spending.
