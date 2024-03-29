library(tidyverse)
library(rethinking)
library(MLmetrics)
select = dplyr::select


ubikedata = read.csv("file:///C:/Users/asus/Desktop/final project/XinyiSquare.csv")
train = ubikedata[1:(24*23),]
test = ubikedata[(24*23+1):721,]


#AR(1) Model


AR1_backtest_model = "
data {
int<lower=0> N;
vector[N] y;
}
parameters {
real alpha;
real beta;
real beta2;
real<lower=0> sigma;
}
model {
for (n in 25:N)
y[n] ~ normal(alpha + beta * y[n-1] + beta2 * y[n-24], sigma);
alpha ~ normal(0,1);
beta ~ normal(0,1);
beta2 ~ normal(0,1);
sigma ~ lognormal(0,1);
}
generated quantities {
vector [N-24] pred_y;
for ( n in 25:N){
pred_y [n-24] = normal_rng(alpha + beta * y[n-1] + beta2 * y[n-24], sigma);}
}
"

data = list(
  N = nrow(ubikedata),
  y = ubikedata$quantity
)

fit1.1 = stan(
  model_code = AR1_backtest_model,
  data = data
)

post1.1 = as.data.frame(fit1.1)
post1.1 = post1.1 %>% select(contains('pred_y'))

actual_data =ubikedata$quantity[25:nrow(ubikedata)]
pred_comp1 = data.frame(actual = actual_data,
                       pred = post1.1 %>% apply(MARGIN = 2, FUN = mean),
                       l_PI = post1.1 %>% apply(MARGIN = 2, FUN = PI) %>% .[1,],
                       h_PI = post1.1 %>% apply(MARGIN = 2, FUN = PI) %>% .[2,])
pred_comp1 %>% ggplot() +
  geom_point(aes(x=1:nrow(pred_comp1), y=actual),color='dodgerblue') +
  geom_line(aes(x=1:nrow(pred_comp1),y=pred))

RMSE(y_pred = pred_comp1$pred, y_true = pred_comp1$actual)




AR1_tandp_model = "
data {
  int<lower=0> N_train;
  vector[N_train] y;
  int N_test;
  int N_total;
  vector[N_total] y2;
}
parameters {
  real alpha;
  real beta;
  real beta2;
  real<lower=0> sigma;
}
model {
  for (n in 25:N_train)
    y[n] ~ normal(alpha + beta * y[n-1] + beta2 * y[n-24], sigma);
  alpha ~ normal(0,1);
  beta ~ normal(0,1);
  beta2 ~ normal(0,1);
  sigma ~ lognormal(0,1);
}
generated quantities {
  vector [N_test] pred_y;
for ( n in N_train+1:N_total){
pred_y [n-N_train] = normal_rng(alpha + beta * y2[n-1] + beta2 * y2[n-24], sigma);}
}
"

data = list(
  N_train = nrow(train),
  y = train$quantity,
  N_test = nrow(test),
  N_total = nrow(ubikedata),
  y2 = ubikedata$quantity
)

fit1.2 = stan(
  model_code = AR1_tandp_model,
  data = data
  )

post1.2 = as.data.frame(fit1.2) %>% 
  select(contains('pred_y'))

actual_data2 =test$quantity
pred_comp2 = data.frame(actual = actual_data2,
                       pred = post1.2 %>% apply(MARGIN = 2, FUN = mean),
                       l_PI = post1.2 %>% apply(MARGIN = 2, FUN = PI) %>% .[1,],
                       h_PI = post1.2 %>% apply(MARGIN = 2, FUN = PI) %>% .[2,])
pred_comp2 %>% ggplot() +
  geom_point(aes(x=1:nrow(pred_comp2), y=actual),color='dodgerblue') +
  geom_line(aes(x=1:nrow(pred_comp2),y=pred))

RMSE(y_pred = pred_comp2$pred, y_true = pred_comp2$actual)










































#ARCH(1) Model

ARCH1_model = "
data {
  int<lower=0> T;   // number of time points
  real r[T];        // return at time t
}
parameters {
  real mu;                       // average return
  real<lower=0> alpha0;          // noise intercept
  real<lower=0,upper=1> alpha1;  // noise slope
}
model {
  for (t in 2:T)
    r[t] ~ normal(mu, sqrt(alpha0 + alpha1 * pow(r[t-1] - mu,2)));
}
"