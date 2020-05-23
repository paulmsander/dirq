# dirq

Dirq 2.0.0

The dirq package provides some simple tools that help to automate storage
management when a process is repeated many times.  It implements queues
of directories of configurable lengths.  In its simplest form, directories
are removed in the order they are created.  However, the directories can
also be given states that can preserve them (make them immune to removal
until they are put back into a removable state).  States can also give an
indication of the "quality" of a directory's contents, which also alters
the removal order; directories are removed in order of increasing quality
then decreasing age.

The dirq program performs the actual management of directory queues.  It
creates new directories (removing old ones if needed to make room in the
queue).  It can also query the state of the queue to provide an easy way
to determine which directory is "best" or predict the next directory to
be removed.

The dirqst program queries and alters the state of a specific directory.
States that participate in dirq's quality assessment are given enumerated
values.  Other states may hold arbitrary ASCII strings.

The quality assessment may be done with state value constants or by
accumulating multiple state values.  This gives a flexible mechanism
in which to represent and compare different levels of quality.

The dirq and dirqst programs also provide a multi-user locking mechanism
that minimizes race conditions in the event that multiple users perform
concurrent operations on queue or a directory.  This is done in a way that
can be extended to larger systems.

A configuration file (named dirq.dat) specifies the queues, their locations,
naming conventions, and lengths.  It also identifies which state values
contribute to quality assessments, and their weights.

Man pages are provided that describe in detail how the tools operate and
how to configure them.

To install the dirq package, run "make -n install" and review the output.
Then become root and run "make install".  Finally, edit the installed
dirq.dat file as needed.

This software is donated to the public domain by its author, Paul Sander
(paul@wakawaka.com).

History:

2.0 -- Remove the -d option from the dirq and dirqst programs.  Add
       a sample pipeline queue type to the dirq.dat file, and document it.
       When creating a new directory, initialize all of the state values
       that contribute to the quality assessment.

1.2 -- Added the -N length option to the dirq program to allow the user to
       override the queue length specified in the dirq.dat file.  Also fixed
       a bug that allowed the predecessor directory to be removed, and
       corrected the documentation.

1.1 -- Added the -P option, which overrides the prefix for the given queue
       type.  This allows multiple queues of the same type to share a parent
       directory.

1.0 -- Changed the format of the dirq.dat file to specify whether directories
       in a queue are named with serial number only or also with a datestamp.
       In serial format, the serial number indicates the creation order.  In
       datestamp format, sort order of the names is the same as the creation
       order.

1.0-beta -- Initial implementation.
