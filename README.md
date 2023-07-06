# SHEBANQ

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
<img src="https://camo.githubusercontent.com/efdbaf92d577bd214ee5f26020d668e470045bd66de29266d8e74f336bd57d05/68747470733a2f2f773369642e6f72672f72657365617263682d746563686e6f6c6f67792d72656164696e6573732d6c6576656c732f4c6576656c3950726f76656e2e737667" alt="Technology Readiness Level 9/9 - Proven - Technology complete and proven in practise by real users" data-canonical-src="https://w3id.org/research-technology-readiness-levels/Level9Proven.svg" style="max-width: 100%;">

![shebanq](/src/shebanq/static/images/shebanq_logo_small.png)
![tf](/src/shebanq/static/images/tf-small.png)
[![etcbc](src/shebanq/static/images/etcbc-small.png)](https://github.com/ETCBC)
[![huc](src/shebanq/static/images/huc-small.png)](https://di.huc.knaw.nl/text-analysis-en.html)

## About

*System for HEBrew Text: ANnotations for Queries and Markup*

[SHEBANQ](http://shebanq.ancient-data.org)
is a website with a search engine for the Hebrew Bible, powered by the
[BHSA](https://github.com/ETCBC/bhsa)
linguistic database, also known as ETCBC or WIVU.

The ETCBC is lead by
[prof. dr. Willem Th. van Peursen](https://research.vu.nl/en/persons/willem-van-peursen).

## History

SHEBANQ was first deployed in 2014, by DANS, for the ETCBC, in the context of CLARIN.

The evolution of SHEBANQ till now can be seen in
[ETCBC/shebanq](https://github.com/ETCBC/shebanq)
which reflects the history of SHEBANQ since October 2017.
It still contains the documentation and lots of useful information.

**begin not yet in effect, upcoming**

Medio summer 2023 SHEBANQ migrated to KNAW/HuC in the context of CLARIAH,
which acts as the successor of CLARIN.

**end not yet in effect, upcoming**

## Deployment

The deployment is now via *docker* and everything needed to deploy SHEBANQ
can be found in this repository.

**You can have your own shebanq!**

Just install the Docker app, clone this repo, copy `env_template` to `.env`,
and give the command:

```
docker compose up -d
```

See [USAGE](USAGE.md) for the ins and outs of this deployment.

**begin not yet in effect, upcoming**

SHEBANQ as seen on
[shebanq.ancient-data.org](https://shebanq.ancient-data.org)
is deployed by
[KNAW/HuC](https://di.huc.knaw.nl/infrastructure-services-en.html).

**end not yet in effect, upcoming**

# Author

[Dirk Roorda](https://github.com/dirkroorda), working at
[KNAW Humanities Cluster - Digital Infrastructure](https://di.huc.knaw.nl/text-analysis-en.html).

See [team](https://github.com/ETCBC/shebanq/wiki/Team) for a list of people
that have contributed in various ways to the existence of the website SHEBANQ.
