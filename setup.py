#!/bin/env python

#######################################################################
#  Copyright (C) 2020 Vinh Tran
#
#  hamstr1s is the python package of the HaMStR-oneSeq orthology prediction
#  tool. hamstr1s is a free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  hamstr1s is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with greedyFAS.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################

from setuptools import setup, find_packages

with open("README.md", "r") as input:
    long_description = input.read()

setup(
    name="hamstr1s",
    version="2.0.0",
    python_requires='>=3.7.0',
    description="Feature-aware orthology prediction tool",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Vinh Tran",
    author_email="tran@bio.uni-frankfurt.de",
    url="https://github.com/BIONF/HaMStR",
    packages=find_packages(),
    package_data={'': ['*']},
    install_requires=[
        'biopython',
        'tqdm',
        'ete3',
        'six',
        'greedyFAS'
    ],
    entry_points={
        'console_scripts': ["oneSeq = hamstr1s.runOneseq:main",
                            "setup1s = hamstr1s.setupOneseq:main",
                            "checkData1s = hamstr1s.checkDataHamstr:main",
                            "addTaxon1s = hamstr1s.addTaxonHamstr:main",
                            "addTaxa1s = hamstr1s.addTaxaHamstr:main",
                            "merge1sOutput = hamstr1s.mergePhyloprofileData:main"],
    },
    license="GPL-3.0",
    classifiers=[
        "Environment :: Console",
        "Intended Audience :: End Users/Desktop",
        "License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)",
        "Natural Language :: English",
        "Programming Language :: Python :: 3",
    ],
)