---
layout: post
title: Calculating WAIC from Bayesian AFT models run in JAGS 
subtitle: How the loo and R2jags packages make Bayesian computation fun and easy in R
tags: [R, RStudio, Jekyll, Github, Markdown]
---



Before I begin this post, I'd like to apologize to all of my dedicated readers (thanks mom) who've been
checking in during the past few months and haven't seen any new posts. 

I took a course in Bayesian methods this past semester, and we ended with a lecture on Bayesian accelerated 
failure time (AFT) models. The details of the AFT model are beyond this post (if you're interested, please get the [Bayesian Ideas and Data Analysis](http://blogs.oregonstate.edu/bida/) book and read chapter 13, which I'm basing this post on), but the basic idea is that we have "failure" times, which are usually times to events such as death
or recurrence of a disease, and we want to model these failure times using covariates. In addition,
it is common to have right-censored observations, which means that we know that the event of interest did not
occur until a certain point, but we do not observe the actual failure time. This often occurs
when subjects drop out of a study, or when a study ends before we are able to observe failure
times for all subjects.

The AFT model is a parametric model, meaning that we assume that the failure times
have a certain distribution. Two common distributions used are the Weibull distribution
and the log-normal distribution. If we decide to use an AFT model, but are not sure
which distribution to use, it might be of use to fit both and find a measure to compare
how well each distribution fits the data. One such measure is the [deviance information criterion](https://en.wikipedia.org/wiki/Deviance_information_criterion), or DIC.
I will be using JAGS (Just Another Gibbs Sampler) to fit these two models, and JAGS conveniently provides the
DIC for each model. However, **DIC is not calculated correctly for models with censored observations in JAGS**,
which I will prove later in this post.

The widely applicable information criteron (WAIC) is 
viewed as an improvement on DIC (Aki Vehtari, Andrew Gelman, and Jonah Gabry have much more on this [here](http://www.stat.columbia.edu/~gelman/research/unpublished/loo_stan.pdf)), and is viewed as
a fully Bayesian way of comparing models. In order to calculate the WAIC, we assume we have 
S draws of the parameters in our model from their posterior distribution, and then we calculate
the log-likelihood for each data point for each of these draws. If we have N observations,
we will then have an N x S matrix of log-likelihoods, and can use the [loo package](https://cran.r-project.org/web/packages/loo/loo.pdf) to calculate the WAIC.

Now let's get to the modeling with R! As I mentioned before, we will be using 
JAGS, which can be downloaded [here](https://sourceforge.net/projects/mcmc-jags/files/).
We will also be using the `data.table`, `R2jags` and `loo` packages in R, so you should install
those if you haven't already. 

The data we will be analyzing is taken from Example 13.1.1 in the Bayesian Ideas and Data Analysis
book that I linked to earlier. The subjects for the data are 90 males with cancer of the larynx, and the outcome
variable of interest is the time from diagnosis to death or censoring. Our covariates
are stage of the disease at diagnosis (from 1-4), the year of diagnosis, and the age at diagnosis. Let's
first read the data in, get rid of unecessary columns, and rename the columns.


```r
library(data.table)
larynx.url <- "http://people.oregonstate.edu/~calverta/BIDA/Chapter13/Larynx-Cancer-Data.txt"
larynx.dat <- fread(larynx.url)
larynx.dat <- larynx.dat[1:90, c(1, 2, 4, 5, 6)]
colnames(larynx.dat) <- c("stage", "time", "age", "yr", "cens_time")
```

Note that if we have a censored observation, the time column will be `NA`,
and the cens_time column will contain the censoring time. I
also subsetted the data to the first 90 observations, as the last set of 
observations in the data were used for different purposes. I will now 
extract each column as a vector, since this is easier for JAGS to work with. 


```r
stage <- larynx.dat$stage
t <- larynx.dat$time
age <- larynx.dat$age
yr <- larynx.dat$yr
c <- larynx.dat$cens_time
```

In order to deal with censoring in JAGS, we first will create a variable that
says whether or not our observation is censored.


```r
is.censored <- is.na(t)
```

We will also change our censoring time variable so that for any non-censored observations,
the variable `c` is greater than the observed time.


```r
c[!is.censored] <- t[!is.censored] + 1
```

The reason we do this is because JAGS
handles censored observations with the `dinterval()` function. For observation i,
our JAGS code will have a line like this:


```r
is.censored[i] ~ dinterval(t[i], c[i])
```

The `dinterval()` function will evaluate to 0 if the first argument is less than
or equal to the second argument, and will evaluate to 1 otherwise. Because is.censored
is 0 for our non-censored observations, we want t to be less than c for these subjects. When
is.censored is 1, because the `t` variable is `NA for the censored observations, JAGS
knows to impute a failure time that is greater than our censoring time for that observation.

Now let's write the Weibull and log-normal models in JAGS. Note that I will be using non-informative
priors. I will not explain every step in this model, since there are lots of
resources out there for learning JAGS. However, I also want to calculate
the log-likelihoods for each observation at each scan. For non-censored
observations, this is simply the log-density. For censored observations,
we must use the log of the survival function, which is the probability of obtaining a survival time
at least as extreme as our censoring time.


```r
larynx.weibull.model <- function() {
    for(i in 1:90){
        sAge[i] <- (age[i] - mean(age[])) / sd(age[])
        sYr[i] <- (yr[i] - mean(yr[])) / sd(yr[])
        is.censored[i] ~ dinterval(t[i], c[i])
        t[i] ~ dweib(shape, lambda[i])
        lambda[i] <- exp(-mu[i] * shape)
        mu[i] <- beta[1] + beta[2]*equals(stage[i], 2) +
            beta[3]*equals(stage[i], 3) + beta[4] * equals(stage[i], 4) +
            beta[5] *sAge[i] + beta[6] *sYr[i]
        
        
        ### calculate log-likelihoods
        y[i] <- ifelse(is.censored[i], c[i], t[i])
        loglik[i] <- log(ifelse(is.censored[i],
                                exp(-lambda[i] * (y[i] ^ shape)),
                                shape * lambda[i] * (y[i] ^ (shape - 1)) * exp(-lambda[i] * (y[i] ^ shape))))
    }
    
    ## priors for betas
    for(j in 1:6){
        beta[j] ~ dnorm(0, 0.001)
    }
    
    ### prior for shape
    shape ~ dgamma(.001, .001)
   
}


larynx.ln.model <- function() {
    for(i in 1:90){
        sAge[i] <- (age[i] - mean(age[])) / sd(age[])
        sYr[i] <- (yr[i] - mean(yr[])) / sd(yr[])
        is.censored[i] ~ dinterval(t[i], c[i])
        t[i] ~ dlnorm(mu[i], tau)
        mu[i] <- beta[1] + beta[2]*equals(stage[i], 2) +
            beta[3]*equals(stage[i], 3) + beta[4] * equals(stage[i], 4) +
            beta[5] *sAge[i] + beta[6] *sYr[i]
        
        ### log-likelihood
        y[i] <- ifelse(is.censored[i], c[i], t[i])
        loglik[i] <- log(ifelse(is.censored[i],
                                  1 - plnorm(y[i], mu[i], tau),
                                  dlnorm(y[i], mu[i], tau)))
    }
    
    ## priors for betas
    for(j in 1:6){
        beta[j] ~ dnorm(0, 0.001)
    }
    
    ### prior on precision
    tau ~ dgamma(.001, .001)
}
```


We can now fit the two models using the `R2jags` package. I set my parameter
vector to only return the draws for the coefficients at each scan, along
with the log-likelihoods. I will use 10,000 iterations, with a burn-in of 1000,
and a thinning parameter of 3. Each model should took my computer about 30
seconds to run.


```r
library(R2jags)
```

```
## Loading required package: rjags
```

```
## Loading required package: coda
```

```
## Linked to JAGS 4.2.0
```

```
## Loaded modules: basemod,bugs
```

```
## 
## Attaching package: 'R2jags'
```

```
## The following object is masked from 'package:coda':
## 
##     traceplot
```

```r
larynx.data <- c("t", "age", "yr", "c", "stage", "is.censored")
larynx.params <- c("beta", "loglik")

larynx.weibull.fit <- jags(data = larynx.data,
                           parameters.to.save = larynx.params,
                           n.chains = 1,
                           n.iter = 10000,
                           n.burnin = 1000,
                           n.thin = 3,
                           model.file = larynx.weibull.model)
```

```
## module glm loaded
```

```
## Compiling model graph
##    Resolving undeclared variables
##    Allocating nodes
## Graph information:
##    Observed stochastic nodes: 140
##    Unobserved stochastic nodes: 47
##    Total graph size: 2742
## 
## Initializing model
```

```r
larynx.ln.fit <- jags(data = larynx.data,
                      parameters.to.save = larynx.params,
                      n.chains = 1,
                      n.iter = 10000,
                      n.burnin = 1000,
                      n.thin = 3,
                      model.file = larynx.ln.model)
```

```
## Compiling model graph
##    Resolving undeclared variables
##    Allocating nodes
## Graph information:
##    Observed stochastic nodes: 140
##    Unobserved stochastic nodes: 47
##    Total graph size: 2241
## 
## Initializing model
```


We can compare the coefficient estimates as follows, using the `matrixStats` package.


```r
library(matrixStats)
weibull.paramlist <- larynx.weibull.fit$BUGSoutput$sims.list
ln.paramlist <- larynx.ln.fit$BUGSoutput$sims.list

### 2.5%, 50% and 97.% for weibull coefficients
colQuantiles(weibull.paramlist$beta, probs = c(.025, .5, .975))
```

```
##            2.5%         50%       97.5%
## [1,]  2.0650218  2.56100867  3.22255810
## [2,] -1.0698571 -0.15369496  0.81935225
## [3,] -1.4199184 -0.66998286  0.02309342
## [4,] -2.6029519 -1.67601729 -0.86959939
## [5,] -0.5473477 -0.20654198  0.09109159
## [6,] -0.2388373  0.07391305  0.41158055
```

```r
### 2.5%, 50% and 97.% for log-normal coefficients
colQuantiles(ln.paramlist$beta, probs = c(.025, .5, .975))
```

```
##            2.5%        50%      97.5%
## [1,]  1.7458899  2.3209185  3.0231148
## [2,] -1.2921459 -0.2410810  0.7543392
## [3,] -1.8559071 -0.9657416 -0.1884367
## [4,] -3.1281712 -2.0165055 -1.0512617
## [5,] -0.5608449 -0.2217514  0.1010787
## [6,] -0.2200562  0.1181072  0.5046185
```

We see that the two models return similar, but not identical, parameter estimates
for the different posterior quantiles. Before I show how to calculate the WAIC
for the two models, let me first show that JAGS does not take into account
censored observations into calculating DIC. The reason for this is due to us having to
enter censored observations as `NA` for our observed failure times (the t variable in the models). 

Part of the DIC calculation is done using the deviance, defined as -2 * log-likelihood, at each scan. We can obtain the deviances for the log-normal model, calculated in JAGS, by doing


```r
jags.ln.dev <- ln.paramlist$deviance
```

and we can calculate the deviances with only the non-censored observations
as follows


```r
ln.loglik <- ln.paramlist$loglik
ln.observed.loglik <- ln.loglik[, !is.censored]

est.ln.dev <- -2 * rowSums(ln.loglik)
est.observed.ln.dev <- -2 * rowSums(ln.observed.loglik)
```

Comparing the deviances calculated with JAGS to the one using all of our observations,
we see that they are very different. However, using the deviances calculated from
the non-censored observations, we see that these are essentially the same as the ones
calculated in JAGS (minus rounding errors)


```r
summary(est.ln.dev - jags.ln.dev)
```

```
##        V1       
##  Min.   :28.62  
##  1st Qu.:43.99  
##  Median :49.22  
##  Mean   :49.66  
##  3rd Qu.:54.60  
##  Max.   :76.52
```

```r
summary(est.observed.ln.dev - jags.ln.dev)
```

```
##        V1            
##  Min.   :-1.705e-13  
##  1st Qu.:-5.684e-14  
##  Median : 0.000e+00  
##  Mean   :-1.032e-14  
##  3rd Qu.: 2.842e-14  
##  Max.   : 1.421e-13
```

Having shown this, I will finally show how to calculate the WAIC for each model with the
`loo` package. I've already extracted the log-likelihoods from the log-normal model above,
so I will first do the same for the Weibull model.


```r
weibull.loglik <- weibull.paramlist$loglik
```

Note that these log-likelihoods are matrices:


```r
dim(weibull.loglik)
```

```
## [1] 3000   90
```

```r
dim(ln.loglik)
```

```
## [1] 3000   90
```

Finally, we simply use the `waic()` function from the `loo` package to calculate the
WAICs.


```r
library(loo)
```

```
## This is loo version 1.1.0
```

```r
ln.waic <- waic(ln.loglik)
```

```
## Warning: 3 (3.3%) p_waic estimates greater than 0.4.
## We recommend trying loo() instead.
```

```r
weibull.waic <- waic(weibull.loglik)

compare(ln.waic, weibull.waic)
```

```
## elpd_diff        se 
##      -0.2       1.7
```

After looking at the `compare` documentation, we see that a negative value
means that the first model, the log-normal model, has a higher predictive
accuracy. 

Thanks for taking the time to read this, I hope you found it helpful! There are a lot of things that I glossed over in this post in order to not take up all of your time, so please get in contact if you have any
questions or comments. 

