# Use the official Python 3.11 image as the base
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    default-jdk \
    procps \
    libatlas-base-dev \
    libopenblas-dev \
    liblapack-dev \
    gfortran \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh \
    && bash miniconda.sh -b -p /opt/conda \
    && rm miniconda.sh \
    && /opt/conda/bin/conda init

# Add conda to PATH
ENV PATH=/opt/conda/bin:$PATH

# Set JAVA_HOME environment variable
RUN echo "export JAVA_HOME=/usr/lib/jvm/default-java" >> /etc/profile.d/jdk.sh \
    && echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/jdk.sh \
    && . /etc/profile.d/jdk.sh

# Install Hadoop
RUN wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz \
    && tar -xzvf hadoop-3.3.6.tar.gz \
    && mv hadoop-3.3.6 /usr/local/hadoop \
    && rm hadoop-3.3.6.tar.gz

# Set HADOOP_HOME and update PATH and LD_LIBRARY_PATH
ENV HADOOP_HOME=/usr/local/hadoop
ENV PATH=$HADOOP_HOME/bin:$PATH
ENV LD_LIBRARY_PATH=$HADOOP_HOME/lib/native:/usr/local/lib:$LD_LIBRARY_PATH

# Create a new conda environment with Python 3.11
RUN conda create -n rapids python=3.11 -y \
    && conda clean -afy

# Activate the environment
SHELL ["conda", "run", "-n", "rapids", "/bin/bash", "-c"]

# Install RAPIDS and other dependencies
RUN conda install -n rapids -c rapidsai -c nvidia -c conda-forge \
    cudatoolkit=11.2 \
    cuml \
    cugraph \
    cudf \
    && conda install -n rapids \
    numpy \
    pandas \
    seaborn \
    scipy \
    matplotlib \
    findspark \
    implicit \
    datasets \
    pyspark \
    jupyter==1.0.0 \
    notebook==7.0.8 \
    && conda install -n rapids -c intel mkl mkl-include mkl-service \
    && conda clean -afy

# Create Jupyter configuration file
RUN mkdir -p ~/.jupyter \
    && echo "c.NotebookApp.token = ''" >> ~/.jupyter/jupyter_notebook_config.py \
    && echo "c.NotebookApp.password = ''" >> ~/.jupyter/jupyter_notebook_config.py \
    && echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py

# Copy the Log4j properties file to /app/config/
COPY log4j.properties /app/config/log4j.properties

# Set the working directory
WORKDIR /workspace

# Expose port for Jupyter
EXPOSE 8889

# Expose Spark web UI ports
EXPOSE 4040 8080 8081

# Set environment variables for MKL
ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

# Start Jupyter Notebook on port 8889
CMD ["conda", "run", "-n", "rapids", "jupyter", "notebook", "--ip", "0.0.0.0", "--port", "8889", "--no-browser", "--allow-root"]