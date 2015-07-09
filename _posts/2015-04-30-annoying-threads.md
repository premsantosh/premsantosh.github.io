---
layout: post
title: Annoying Threads
description: Control calling a variable number of threads with different return types
category: Java
tags: [threads]

excerpt : Control calling a variable number of threads with different return types

---

Recently while working with threads, I came across an issue where I had to make calls to multiple threads without waiting for the reply from the previous thread. So basically make all calls to threads and wait on every thread to join. Why not just do this:

{% highlight java %}
Future<T> futureOne = cachePool.submit(new Callable<A> () {
  @Override
  public A call() {
    return A;
  });

Future<T> futureTwo = cachePool.submit(new Callable<A> () {
  @Override
  public A call() {
    return A;
  });

futureOne.get();
futureTwo.get();
{% endhighlight %}

This sounds simple enough but the problem becomes convoluted when you do not know how many calls you need to make ahead of time and when all the calls return a different future generic. Now you don't want to write multiple if() conditions to check if you need to make a call to a particular thread or not cause it gets ugly. This is when you can make use of the beautiful things in java called enums.

Lets create an interface `Futures` and have all the methods, that require threading, implement it. We can then create an enum for each one of those methods as follows:

{% highlight java %}
public enum ThreadedMethods {
  METHOD_ONE {
    @Override
    public Callable<Futures> perform() {
      return new Callable<Futures>() {
        @Override
        public Futures call() throws InterruptedException {
          // Do something
          return new Futures();
        }
      }
    }
  },

  METHOD_TWO {
    @Override
    public Callable<Futures> perform() {
      return new Callable<Futures>() {
        @Override
        public Futures call() throws InterruptedException {
          // Do something
          return new Futures();
        }
      }
    }
  }

  public abstract Callable<Futures> perform() throws InterruptedException;
}
{% endhighlight %}

Now have a map to store all the futures returned and access them after a timeout.

{% highlight java %}
Map<ThreadedMethods, Future<Futures>> allFutures = Maps.newHashMap();
{% endhighlight %}
